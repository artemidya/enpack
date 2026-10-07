#!/usr/bin/env python3
"""Execute x64 startup machine code with mocked WinAPI/COM in Unicorn.

NOT a substitute for running CorelDRAW on Windows. No packing is emulated.
Dependencies: pefile, unicorn. Usage: python tools/test_startup_emulated.py FILE.cpg
"""
import struct
import sys
from pathlib import Path
import pefile
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE, UC_HOOK_INSN
from unicorn.x86_const import *
from check_typelib import interfaces


def qword(value):
    return struct.pack('<Q', value)


class Host:
    def __init__(self, filename, scenario):
        self.scenario = scenario
        self.pe = pefile.PE(filename)
        assert self.pe.FILE_HEADER.Machine == 0x8664
        self.uc = Uc(UC_ARCH_X86, UC_MODE_64)
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.uc.mem_map(self.base, self.pe.OPTIONAL_HEADER.SizeOfImage)
        self.uc.mem_write(self.base, self.pe.get_memory_mapped_image())
        self.uc.mem_map(0x10000000, 0x100000)
        self.uc.mem_map(0x20000000, 0x100000)
        self.uc.mem_map(0x30000000, 0x100000)
        self.next_stub = 0x10000000
        self.next_heap = 0x30000000
        self.stop = 0x100F0000
        self.uc.mem_write(self.stop, b'\xc3')
        self.handlers = {}
        self.log = []
        self.files = {}
        self.file_id = 100
        self.calls = []
        self.refcounts = {}
        self.bstrs = set()
        self.uc.hook_add(UC_HOOK_CODE, self.on_code)
        self.uc.hook_add(UC_HOOK_INSN, self.cpuid, None, 1, 0, UC_X86_INS_CPUID)
        for entry in self.pe.DIRECTORY_ENTRY_IMPORT:
            for imp in entry.imports:
                name = imp.name.decode()
                address = self.stub(lambda a, name=name: self.api(name, a))
                self.uc.mem_write(imp.address, qword(address))
        self.inc = interfaces(Path('src/x64/CorelDraw.inc').read_text('cp1251'))
        self.objects = {}
        for name, interface in [('app', 'IVGApplication'), ('bars', 'ICUICommandBars'),
                                ('bar', 'ICUICommandBar'), ('controls', 'ICUIControls'),
                                ('control', 'ICUIControl')]:
            self.objects[name] = self.object(name, interface)
        self.plugin = 0

    def alloc(self, size):
        ptr = self.next_heap
        self.next_heap += (size + 15) & ~15
        return ptr

    def stub(self, handler):
        ptr = self.next_stub
        self.next_stub += 16
        self.handlers[ptr] = handler
        self.uc.mem_write(ptr, b'\xc3')
        return ptr

    def object(self, name, interface):
        ptr = self.alloc(8)
        vtable = self.alloc(len(self.inc[interface]) * 8)
        self.uc.mem_write(ptr, qword(vtable))
        for i, method in enumerate(self.inc[interface]):
            address = self.stub(lambda a, n=name, m=method: self.com(n, m, a))
            self.uc.mem_write(vtable + i * 8, qword(address))
        self.refcounts[name] = 0
        return ptr

    def cpuid(self, uc, _):
        uc.reg_write(UC_X86_REG_ECX, 0 if self.scenario == 'no_sse41' else 1 << 19)
        return True

    def on_code(self, uc, address, size, _):
        if address == self.stop:
            uc.emu_stop()
        elif address in self.handlers:
            sp = uc.reg_read(UC_X86_REG_RSP)
            assert sp % 16 == 8, f'Unaligned Win64 call: {sp:x}'
            args = [uc.reg_read(r) for r in (UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9)]
            args += list(struct.unpack('<4Q', uc.mem_read(sp + 40, 32)))
            result = self.handlers[address](args)
            # Volatile registers may be destroyed by a real external function.
            for reg in (UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9,
                        UC_X86_REG_R10, UC_X86_REG_R11):
                uc.reg_write(reg, 0xBAD00000)
            uc.reg_write(UC_X86_REG_RAX, result & 0xFFFFFFFFFFFFFFFF)

    def string(self, ptr, wide=False):
        data = bytearray()
        step = 2 if wide else 1
        for i in range(4096):
            part = self.uc.mem_read(ptr + i * step, step)
            if not any(part):
                return data.decode('utf-16le' if wide else 'ascii')
            data += part
        raise AssertionError('Unterminated string')

    def write_string(self, ptr, value, wide=False):
        self.uc.mem_write(ptr, (value + '\0').encode('utf-16le' if wide else 'ascii'))

    def out(self, ptr, value, size=8):
        self.uc.mem_write(ptr, value.to_bytes(size, 'little', signed=False))

    def return_object(self, output, name):
        self.out(output, self.objects[name])
        self.refcounts[name] += 1
        return 0

    def api(self, name, a):
        if name == 'GetTempPathW':
            if self.scenario == 'no_temp':
                return 0
            self.write_string(a[1], 'C:\\Temp\\', True)
            return 8
        if name == 'lstrcatW':
            self.write_string(a[0], self.string(a[0], True) + self.string(a[1], True), True)
            return a[0]
        if name == 'lstrlenW':
            return len(self.string(a[0], True))
        if name == 'lstrcmpW':
            x, y = self.string(a[0], True), self.string(a[1], True)
            return (x > y) - (x < y)
        if name == 'CreateFileW':
            path = self.string(a[0], True)
            if self.scenario == 'icon_failure' and path.endswith('.ico'):
                return -1
            self.file_id += 1
            self.files[self.file_id] = path
            return self.file_id
        if name == 'wsprintfA':
            text = '%s HRESULT=0x%08X\r\n' % (self.string(a[2]), a[3] & 0xFFFFFFFF)
            self.write_string(a[0], text)
            return len(text)
        if name == 'WriteFile':
            if self.files[a[0]].endswith('.log'):
                self.log.append(bytes(self.uc.mem_read(a[1], a[2])).decode('ascii').strip())
            self.out(a[3], a[2], 4)
            return 1
        if name == 'CloseHandle':
            del self.files[a[0]]
            return 1
        if name == 'SysFreeString':
            assert a[0] in self.bstrs
            self.bstrs.remove(a[0])
            return 0
        if name == 'MessageBoxW':
            return 1
        raise AssertionError(f'Unexpected API: {name}')

    def com(self, obj, method, a):
        self.calls.append((obj, method))
        if method in ('AddRef', 'Release'):
            self.refcounts[obj] += 1 if method == 'AddRef' else -1
            assert self.refcounts[obj] >= 0, (obj, method, self.refcounts)
            return self.refcounts[obj]
        if method in ('Get_VersionMajor', 'Get_VersionMinor'):
            self.out(a[1], 27 if method.endswith('Major') else 2, 4)
        elif method == 'AddPluginCommand':
            if self.scenario == 'register_failure':
                return 0x80004005
            self.out(a[4], 0 if self.scenario == 'register_false' else 65535, 2)
        elif method == 'RemovePluginCommand':
            self.out(a[2], 65535, 2)
        elif method == 'AdviseEvents':
            if self.scenario == 'advise_failure':
                return 0x80004005
            self.out(a[2], 123, 4)
        elif method == 'UnadviseEvents':
            assert a[1] == 123
        elif method == 'Get_CommandBars':
            if self.scenario == 'bars_null':
                self.out(a[1], 0)
                return 0
            return self.return_object(a[1], 'bars')
        elif obj == 'bars' and method == 'Get_Item':
            # Win64 ABI passes this 24-byte VARIANT by reference.
            assert struct.unpack('<H', self.uc.mem_read(a[1], 2))[0] == 8
            value = struct.unpack('<Q', self.uc.mem_read(a[1] + 8, 8))[0]
            label = self.string(value, True)
            if label == 'DirectEnpack' or self.scenario == 'missing_standard':
                return 0x8002000B
            return self.return_object(a[2], 'bar')
        elif obj == 'bars' and method == 'Add':
            if self.scenario == 'fallback_failure':
                return 0x80004005
            return self.return_object(a[4], 'bar')
        elif method == 'Get_Visible':
            self.out(a[1], 0 if self.scenario in ('hidden_standard', 'fallback_failure') else 65535, 2)
        elif method == 'Set_Visible':
            pass
        elif method == 'Get_Controls':
            return self.return_object(a[1], 'controls')
        elif method == 'Get_Count':
            self.out(a[1], 0 if self.scenario == 'empty_bar' else 1, 4)
        elif obj == 'controls' and method == 'Get_Item':
            assert a[1] == 1, 'Must never request Controls.Item(0)'
            return self.return_object(a[2], 'control')
        elif method == 'Get_Caption':
            text = 'Прямоугольный раскрой' if self.scenario == 'existing_button' else 'Other'
            bstr = self.alloc(4 + (len(text) + 1) * 2) + 4
            self.out(bstr - 4, len(text) * 2, 4)
            self.write_string(bstr, text, True)
            self.bstrs.add(bstr)
            self.out(a[1], bstr)
        elif method == 'AddCustomButton':
            if self.scenario == 'button_failure':
                return 0x80004005
            return self.return_object(a[5], 'control')
        elif method == 'SetIcon2':
            text = self.string(a[1], True)
            assert struct.unpack('<I', self.uc.mem_read(a[1] - 4, 4))[0] == len(text) * 2
        else:
            raise AssertionError(f'Unexpected COM call: {obj}.{method}')
        return 0

    def call(self, address, *args):
        sp = 0x200FF008
        self.uc.mem_write(sp, qword(self.stop))
        self.uc.reg_write(UC_X86_REG_RSP, sp)
        for reg, arg in zip((UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9), args):
            self.uc.reg_write(reg, arg)
        saved = {}
        for index, reg in enumerate((UC_X86_REG_RBX, UC_X86_REG_RBP, UC_X86_REG_RSI,
                                    UC_X86_REG_RDI, UC_X86_REG_R12, UC_X86_REG_R13,
                                    UC_X86_REG_R14, UC_X86_REG_R15)):
            saved[reg] = 0x50000000 + index
            self.uc.reg_write(reg, saved[reg])
        self.uc.emu_start(address, self.stop + 1, count=500000)
        assert self.uc.reg_read(UC_X86_REG_RIP) == self.stop, 'Execution did not return'
        assert self.uc.reg_read(UC_X86_REG_RSP) == sp + 8
        for reg, value in saved.items():
            assert self.uc.reg_read(reg) == value, f'Nonvolatile register not preserved: {reg}'
        return self.uc.reg_read(UC_X86_REG_EAX)

    def callback(self, slot, *args):
        table = struct.unpack('<Q', self.uc.mem_read(self.plugin, 8))[0]
        address = struct.unpack('<Q', self.uc.mem_read(table + slot * 8, 8))[0]
        return self.call(address, self.plugin, *args)

    def run(self):
        assert self.call(self.base + self.pe.OPTIONAL_HEADER.AddressOfEntryPoint, self.base, 1, 0) == 1
        attach = next(s.address for s in self.pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name == b'AttachPlugin')
        output = self.alloc(8)
        assert self.call(self.base + attach, output) == 256
        self.plugin = struct.unpack('<Q', self.uc.mem_read(output, 8))[0]
        assert self.callback(7, self.objects['app']) == 0
        result = self.callback(8)
        failures = ('register_failure', 'register_false', 'advise_failure', 'bars_null',
                    'button_failure', 'fallback_failure', 'no_sse41')
        assert bool(result & 0x80000000) == (self.scenario in failures), (result, self.log)
        if self.scenario not in failures and self.scenario != 'no_temp':
            assert any('READY:' in line for line in self.log)
        if self.scenario == 'existing_button':
            assert ('controls', 'AddCustomButton') not in self.calls
        if self.scenario in ('missing_standard', 'hidden_standard'):
            assert ('bars', 'Add') in self.calls
        assert self.callback(9) == 0
        assert self.callback(10) == 0
        assert not any(self.refcounts.values()), self.refcounts
        assert not self.bstrs
        assert not self.files
        assert self.calls.count(('app', 'UnadviseEvents')) <= 1
        assert self.calls.count(('app', 'RemovePluginCommand')) <= 1


if __name__ == '__main__':
    for scenario in ('normal', 'empty_bar', 'existing_button', 'missing_standard', 'hidden_standard',
                     'icon_failure', 'no_temp', 'register_failure', 'register_false', 'advise_failure',
                     'bars_null', 'button_failure', 'fallback_failure', 'no_sse41'):
        host = Host(sys.argv[1], scenario)
        try:
            host.run()
        except Exception:
            print('FAIL:', scenario, 'log:', host.log, 'calls:', host.calls)
            raise
        print('PASS:', scenario)

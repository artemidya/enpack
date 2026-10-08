#!/usr/bin/env python3
"""Execute SmartDepart x64 lifecycle/binding under mocked COM, NOT CorelDRAW.

No geometry commands are executed. Dependencies: requirements-test.txt.
"""
import struct
import sys
from pathlib import Path
from unicorn.x86_const import UC_X86_REG_ECX, UC_X86_REG_RBX
from test_startup_emulated import Host, qword
from check_typelib import interfaces


class SmartHost(Host):
    def __init__(self, filename, scenario):
        super().__init__(filename, scenario)
        self.inc = interfaces(Path('src/smartdepart/x64/CorelDraw.inc').read_text('cp1251'))
        self.objects['app'] = self.object('app', 'IVGApplication')
        self.objects['cui'] = self.object('cui', 'ICUIApplication')
        self.factory = 0
        self.version_outputs = []

    def cpuid(self, uc, unused):
        # Real CPUID overwrites RBX: this detects the upstream Win64 ABI bug.
        uc.reg_write(UC_X86_REG_RBX, 0xC0FFEE)
        flags = (1 << 20) | (1 << 23)
        if self.scenario == 'no_sse42': flags &= ~(1 << 20)
        if self.scenario == 'no_popcnt': flags &= ~(1 << 23)
        uc.reg_write(UC_X86_REG_ECX, flags)
        return True

    def api(self, name, args):
        if name == 'MessageBoxW': return 1
        raise AssertionError('Unexpected API (geometry must not run): ' + name)

    def com(self, obj, method, a):
        self.calls.append((obj, method))
        if method in ('AddRef', 'Release'):
            self.refcounts[obj] += 1 if method == 'AddRef' else -1
            assert self.refcounts[obj] >= 0
            return self.refcounts[obj]
        if method in ('Get_VersionMajor', 'Get_VersionMinor'):
            if self.scenario == ('major_failure' if method.endswith('Major') else 'minor_failure'):
                return 0x80004005
            self.version_outputs.append(a[1])
            self.out(a[1], 27 if method.endswith('Major') else 2, 4)
        elif method == 'QueryInterface':
            assert bytes(self.uc.mem_read(a[1], 16)).hex() == '0a00ee9ca042805943a37aa71461482c'
            if self.scenario == 'qi_failure': return 0x80004002
            if self.scenario == 'null_cui':
                self.out(a[2], 0)
                return 0
            return self.return_object(a[2], 'cui')
        elif method == 'RegisterDataSource':
            assert self.string(a[1], True) == 'SmartDepart'
            assert a[4] == 0
            self.factory = a[2]
            if self.scenario == 'register_failure': return 0x80004005
            self.out(a[5], 0 if self.scenario == 'register_false' else 65535, 2)
        elif method == 'UnregisterDataSource':
            assert self.string(a[1], True) == 'SmartDepart'
            self.out(a[2], 65535, 2)
        else:
            raise AssertionError('Unexpected COM/geometry call: ' + obj + '.' + method)
        return 0

    def call(self, address, *args):
        if len(args) > 4:
            self.uc.mem_write(0x200FF008 + 40, b''.join(qword(a) for a in args[4:]))
        return super().call(address, *args[:4])

    def verify_binding(self):
        # Factory must supply the data source used by *Bind(DataSource=SmartDepart).
        table = struct.unpack('<Q', self.uc.mem_read(self.factory, 8))[0]
        create = struct.unpack('<Q', self.uc.mem_read(table + 7 * 8, 8))[0]
        output = self.alloc(8)
        assert self.call(create, self.factory, 0, 0, output) == 0
        assert struct.unpack('<Q', self.uc.mem_read(output, 8))[0] == self.plugin
        count = self.alloc(4)
        assert self.callback(3, count) == 0
        assert struct.unpack('<I', self.uc.mem_read(count, 4))[0] == 1
        variant = self.alloc(24)
        assert self.callback(6, 4, 0, 0, 2, 0, variant, 0, 0) == 0
        assert struct.unpack('<d', self.uc.mem_read(variant + 8, 8))[0] == 0.1
        args = self.alloc(24)
        self.uc.mem_write(args, struct.pack('<QdQ', 5, 0.25, 0))
        params = self.alloc(24)
        named = self.alloc(4)
        self.out(named, 0xFFFFFFFD, 4)  # DISPID_PROPERTYPUT
        self.uc.mem_write(params, struct.pack('<QQII', args, named, 1, 1))
        assert self.callback(6, 4, 0, 0, 4, params, 0, 0, 0) == 0
        assert self.callback(6, 4, 0, 0, 2, 0, variant, 0, 0) == 0
        assert struct.unpack('<d', self.uc.mem_read(variant + 8, 8))[0] == 0.25

    def run(self):
        assert self.call(self.base + self.pe.OPTIONAL_HEADER.AddressOfEntryPoint, self.base, 1, 0) == 1
        attach = next(s.address for s in self.pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name == b'AttachPlugin')
        output = self.alloc(8)
        assert self.call(self.base + attach, output) == 256
        self.plugin = struct.unpack('<Q', self.uc.mem_read(output, 8))[0]
        app = 0 if self.scenario == 'null_app' else self.objects['app']
        result = self.callback(7, app)
        if self.scenario in ('normal', 'double_load'):
            assert result == 0
            assert len(self.version_outputs) == 2 and abs(self.version_outputs[0] - self.version_outputs[1]) >= 4
            if self.scenario == 'double_load':
                assert self.callback(7, app) == 0x8000FFFF
            assert self.callback(8) == 0
            self.verify_binding()
        else:
            assert result & 0x80000000, (self.scenario, result)
            assert self.callback(8) == 0x80004005
        assert self.callback(9) == 0
        assert self.callback(10) == 0
        assert self.callback(10) == 0  # Failed load/CPU rejection must not double-release.
        assert not any(self.refcounts.values()), self.refcounts
        assert self.calls.count(('cui', 'UnregisterDataSource')) == (1 if self.scenario in ('normal','double_load') else 0)


if __name__ == '__main__':
    for scenario in ('normal', 'double_load', 'null_app', 'no_sse42', 'no_popcnt',
                     'major_failure', 'minor_failure', 'qi_failure', 'null_cui',
                     'register_failure', 'register_false'):
        SmartHost(sys.argv[1], scenario).run()
        print('PASS:', scenario)

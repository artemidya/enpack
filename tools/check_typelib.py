#!/usr/bin/env python3
"""Check the MSFT x64 type-library vtable slots used by the FASM source.

This is a targeted metadata check, not a Windows loader or runtime test.
Layout reference: Wine dlls/oleaut32/typelib.h (MSFT format).
Only raw MSFT SYS_WIN64 libraries are accepted; no binary code is executed.
"""
import argparse
import hashlib
import re
import struct
from pathlib import Path


class TypeLibrary:
    def __init__(self, data):
        self.data = data
        if data[:4] != b'MSFT':
            raise ValueError('Expected a raw MSFT type library')
        flags = self.u32(0x14)
        if flags & 15 != 3:
            raise ValueError('Expected SYS_WIN64')
        self.version = (self.u32(0x18) & 65535, self.u32(0x18) >> 16)
        count = self.u32(0x20)
        if not 0 < count <= len(data) // 100:
            raise ValueError('Invalid type count')
        table = 0x54 + (4 if flags & 0x100 else 0)
        directory = table + count * 4
        self.segments = [(self.i32(directory + i * 16), self.u32(directory + i * 16 + 4))
                         for i in range(15)]
        for start, length in self.segments:
            if length:
                self.span(start, length)
        self.name = self.get_name(self.i32(0x38))
        self.types = {}
        for i in range(count):
            pos = self.segment(0, self.u32(table + 4 * i), 100)
            name = self.get_name(self.i32(pos + 0x34))
            nf, nv = self.u16(pos + 24), self.u16(pos + 26)
            base = self.i32(pos + 4)
            methods = []
            if nf:
                size = self.u32(base)
                self.span(base + 4, size + (nf + nv) * 12)
                arrays = base + 4 + size
                for j in range(nf):
                    record = base + 4 + self.u32(arrays + (nf + nv) * 8 + j * 4)
                    record_size = self.u16(record)
                    if record_size < 24 or record + record_size > base + 4 + size:
                        raise ValueError('Invalid function record')
                    invocation = (self.u32(record + 16) >> 3) & 15
                    method_name = self.get_name(self.i32(arrays + (nf + nv) * 4 + j * 4))
                    prefix = {2: 'Get_', 4: 'Set_', 8: 'Set_'}.get(invocation, '')
                    offset = self.u16(record + 12)
                    if offset % 8:
                        raise ValueError('Unaligned x64 vtable slot')
                    methods.append({'name': prefix + method_name, 'slot': offset // 8,
                                    'dispid': self.u32(arrays + j * 4),
                                    'arguments': self.u16(record + 20)})
            self.types[name] = methods

    def span(self, offset, length):
        if offset < 0 or length < 0 or offset + length > len(self.data):
            raise ValueError('Truncated or invalid type library')
        return self.data[offset:offset + length]

    def u32(self, pos):
        return struct.unpack('<I', self.span(pos, 4))[0]

    def i32(self, pos):
        return struct.unpack('<i', self.span(pos, 4))[0]

    def u16(self, pos):
        return struct.unpack('<H', self.span(pos, 2))[0]

    def segment(self, index, offset, length):
        start, size = self.segments[index]
        if offset < 0 or offset + length > size:
            raise ValueError('Invalid segment reference')
        return start + offset

    def get_name(self, offset):
        pos = self.segment(7, offset, 12)
        length = self.u32(pos + 8) & 255
        self.segment(7, offset + 12, length)
        return self.span(pos + 12, length).decode('cp1252')


def interfaces(text):
    result = {}
    for match in re.finditer(r'^interface (\w+),\\\n(.*?)(?=\n\n|\Z)', text, re.M | re.S):
        result[match[1]] = [line.split(';')[0].strip().rstrip('\\').rstrip(',').strip()
                            for line in match[2].splitlines()]
    return result


def check(tlb_path, source_dir):
    data = tlb_path.read_bytes()
    tlb = TypeLibrary(data)
    inc = interfaces((source_dir / 'CorelDraw.inc').read_text('cp1251'))
    asm = '\n'.join(p.read_text('cp1251') for p in sorted(source_dir.glob('*'))
                    if p.suffix in ('.asm', '.inc') and p.name != 'CorelDraw.inc')
    # Strip comments before extracting actual calls.
    asm = '\n'.join(line.split(';')[0] for line in asm.splitlines())
    objects = dict(re.findall(r'^(\w+)\s+(I\w+)\s*$', asm, re.M))
    calls = {(objects[obj], method) for obj, method in re.findall(r'cominvk\s+(\w+),(\w+)', asm)}
    calls |= set(re.findall(r'comcall\s+[^,\n]+,(I\w+),(\w+)', asm))
    lines = [f'# Interface check: {tlb.name} {tlb.version[0]}.{tlb.version[1]} (x64)', '',
             f'TLB SHA-256: `{hashlib.sha256(data).hexdigest()}`', '',
             f'Source: `{source_dir.as_posix()}`', '',
             'This checks vtable slots and event DISPIDs only, not parameter types,',
             'Windows loading, UI behavior or packing correctness.', '',
             '| Interface | Method | Source slot | TLB slot | Result |',
             '|---|---|---:|---:|---|']
    errors = 0
    checked = 0
    for interface, method in sorted(calls):
        if method in ('QueryInterface', 'AddRef', 'Release'):
            continue  # Standard IUnknown ABI, inherited from an external library.
        old_slot = inc[interface].index(method)
        matches = [f for f in tlb.types[interface] if f['name'] == method]
        new_slot = matches[0]['slot'] if len(matches) == 1 else None
        ok = old_slot == new_slot
        errors += not ok
        checked += 1
        lines.append(f'| {interface} | {method} | {old_slot} | {new_slot} | {"PASS" if ok else "FAIL"} |')
    lines += ['', '## Application event DISPIDs', '']
    for event in ('SelectionChange', 'OnPluginCommand', 'OnUpdatePluginCommand'):
        match = re.search(rf'^{event}\s*=\s*([0-9A-Fa-f]+)h', asm, re.M)
        expected = int(match[1], 16)
        actual = next(f['dispid'] for f in tlb.types['IVGApplicationEvents'] if f['name'] == event)
        errors += expected != actual
        lines.append(f'- {event}: source={expected}, TLB={actual}, {"PASS" if expected == actual else "FAIL"}')
    lines += ['', f'Checked {checked} Corel/UI methods and 3 events; mismatches: {errors}.', '']
    return '\n'.join(lines), errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tlb', type=Path)
    parser.add_argument('--source', type=Path, default=Path('src/x64'))
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report, errors = check(args.tlb, args.source)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding='utf-8')
    else:
        print(report)
    raise SystemExit(1 if errors else 0)

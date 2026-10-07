#!/usr/bin/env python3
"""Source invariants and defensive parser checks; stdlib only."""
import unittest
from pathlib import Path
from check_typelib import TypeLibrary

ROOT = Path(__file__).resolve().parents[1]


class SourceTests(unittest.TestCase):
    def test_packing_dialog_and_events_are_unchanged(self):
        original = (ROOT / 'upstream/x64/DirectEnpackx64.asm').read_text('cp1251')
        adapted = (ROOT / 'src/x64/DirectEnpackx64.asm').read_text('cp1251')
        expected = original[original.index('BufStr2IntW:'):original.index('proc OnLoad uses rbx')]
        actual = adapted[adapted.index('BufStr2IntW:'):adapted.index("include 'Startup27.inc'")]
        self.assertEqual(expected, actual)

    def test_interface_tables_are_unchanged(self):
        self.assertEqual((ROOT / 'upstream/x64/CorelDraw.inc').read_bytes(),
                         (ROOT / 'src/x64/CorelDraw.inc').read_bytes())

    def test_icons_are_unchanged(self):
        for name in ('icon.ico', 'icon.bmp'):
            self.assertEqual((ROOT / 'upstream' / name).read_bytes(), (ROOT / 'src' / name).read_bytes())

    def test_rejects_invalid_type_library(self):
        for data in (b'', b'Not a typelib', b'MSFT', b'MSFT' + bytes(100)):
            with self.subTest(length=len(data)), self.assertRaises(ValueError):
                TypeLibrary(data)

    def test_rejects_truncated_x64_library(self):
        data = bytearray(0x54)
        data[:4] = b'MSFT'
        data[0x14] = 3
        data[0x20] = 1
        with self.assertRaises(ValueError):
            TypeLibrary(data)


if __name__ == '__main__':
    unittest.main()

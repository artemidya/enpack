#!/usr/bin/env python3
"""Stdlib-only tests for the CDWS icon patch; no CorelDRAW required."""
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from fix_workspace_icon import (ICON_PATH, ICON_URI, PLUGIN_CATEGORY, WORKSPACE_PATH,
                                fix_workspace, patch_xml, validate_icon)

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / 'upstream/icon.ico'
TARGET = f'<itemData guid="target" dynamicCommand="DirectEnpack" dynamicCategory="{PLUGIN_CATEGORY}"></itemData>'


class WorkspaceIconTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'original.cdws'
        self.output = self.root / 'fixed.cdws'

    def archive(self, xml=None, extra=None):
        with zipfile.ZipFile(self.source, 'w') as archive:
            archive.comment = b'Preserve this archive comment'
            archive.writestr('mimetype', b'application/x-coreldraw-workspace')
            archive.writestr(WORKSPACE_PATH, xml or ('<uiConfig><items>' + TARGET + '</items></uiConfig>').encode())
            archive.writestr('content/settings.ini', b'\xff\xfe' + 'Settings remain unchanged'.encode('utf-16le'))
            archive.writestr('content/icons/unrelated.ico', b'unrelated content must be untouched')
            for key, value in (extra or {}).items():
                archive.writestr(key, value)

    def test_embeds_exact_original_and_preserves_every_other_member(self):
        self.archive()
        original_bytes = self.source.read_bytes()
        report = fix_workspace(self.source, self.output, ICON)
        self.assertEqual(self.source.read_bytes(), original_bytes)
        self.assertEqual(report['item_guids'], ['target'])
        with zipfile.ZipFile(self.source) as original, zipfile.ZipFile(self.output) as output:
            self.assertIsNone(output.testzip())
            self.assertEqual(set(output.namelist()) - set(original.namelist()), {ICON_PATH})
            self.assertEqual(output.comment, original.comment)
            self.assertEqual(output.read(ICON_PATH), ICON.read_bytes())
            for name in original.namelist():
                if name != WORKSPACE_PATH:
                    self.assertEqual(original.read(name), output.read(name))
                old_info, new_info = original.getinfo(name), output.getinfo(name)
                for field in ('date_time', 'compress_type', 'comment', 'extra', 'external_attr'):
                    self.assertEqual(getattr(old_info, field), getattr(new_info, field))
            expected = original.read(WORKSPACE_PATH).replace(b'></itemData>',
                f' icon="{ICON_URI}"></itemData>'.encode())
            self.assertEqual(output.read(WORKSPACE_PATH), expected)

    def test_updates_all_three_entries_and_leaves_other_commands_and_categories(self):
        targets = [TARGET.replace('guid="target"', f'guid="{i}"') for i in range(3)]
        other = TARGET.replace('DirectEnpack', 'Bleeds')
        macro = TARGET.replace(PLUGIN_CATEGORY, '2cc24a3e-fe24-4708-9a74-9c75406eebcd')
        xml = ('<uiConfig>' + ''.join(targets) + other + macro + '</uiConfig>').encode()
        result, guids = patch_xml(xml)
        self.assertEqual(guids, ['0', '1', '2'])
        self.assertEqual(result.count(ICON_URI.encode()), 3)
        self.assertIn(other.encode(), result)
        self.assertIn(macro.encode(), result)

    def test_self_closing_single_quoted_and_existing_icon(self):
        xml = (f"<uiConfig><itemData guid='one' dynamicCategory='{PLUGIN_CATEGORY}' "
               "dynamicCommand='DirectEnpack' icon='file:///C:/old.ico'/></uiConfig>").encode()
        result, guids = patch_xml(xml)
        self.assertEqual(guids, ['one'])
        self.assertEqual(result.count(b'icon='), 1)
        self.assertNotIn(b'C:/old.ico', result)
        self.assertIn(ICON_URI.encode(), result)

    def test_patching_twice_is_idempotent_at_member_level(self):
        self.archive()
        fix_workspace(self.source, self.output, ICON)
        third = self.root / 'fixed-again.cdws'
        fix_workspace(self.output, third, ICON)
        with zipfile.ZipFile(self.output) as once, zipfile.ZipFile(third) as twice:
            self.assertEqual(once.namelist(), twice.namelist())
            for name in once.namelist():
                self.assertEqual(once.read(name), twice.read(name))

    def test_refuses_to_overwrite_original_or_existing_output(self):
        self.archive()
        original_bytes = self.source.read_bytes()
        with self.assertRaises(ValueError):
            fix_workspace(self.source, self.source, ICON)
        self.output.write_bytes(b'Keep existing file')
        with self.assertRaises(FileExistsError):
            fix_workspace(self.source, self.output, ICON)
        self.assertEqual(self.source.read_bytes(), original_bytes)
        self.assertEqual(self.output.read_bytes(), b'Keep existing file')

    def test_no_command_means_no_output(self):
        self.archive(b'<uiConfig/>')
        with self.assertRaises(ValueError):
            fix_workspace(self.source, self.output, ICON)
        self.assertFalse(self.output.exists())

    def test_conflicting_embedded_icon_is_not_overwritten(self):
        self.archive(extra={ICON_PATH: b'Different image'})
        with self.assertRaises(ValueError):
            fix_workspace(self.source, self.output, ICON)
        self.assertFalse(self.output.exists())

    def test_malformed_xml_rejected(self):
        self.archive(b'<uiConfig>')
        with self.assertRaises(ET.ParseError):
            fix_workspace(self.source, self.output, ICON)
        self.assertFalse(self.output.exists())

    def test_dtd_rejected(self):
        with self.assertRaises(ValueError):
            patch_xml(b'<!DOCTYPE uiConfig [<!ENTITY a "test">]><uiConfig/>')

    def test_original_ico_valid_but_truncations_rejected(self):
        data = ICON.read_bytes()
        validate_icon(data)
        for truncated in (data[:3], data[:21], data[:-1]):
            with self.subTest(size=len(truncated)), self.assertRaises(ValueError):
                validate_icon(truncated)

    def test_duplicate_zip_members_rejected(self):
        import warnings
        self.archive()
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            with zipfile.ZipFile(self.source, 'a') as archive:
                archive.writestr(WORKSPACE_PATH, b'<uiConfig/>')
        with self.assertRaises(ValueError):
            fix_workspace(self.source, self.output, ICON)
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
import hashlib
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET
from create_workspace import (add_button, additions, create_workspace, original_pixels,
                              rgba_icon, insertion_fragments, BUTTON_ID, ICON_PATH, STANDARD_BAR, XML_PATH, ROOT)


class CleanWorkspaceTests(unittest.TestCase):
    def xml(self):
        return (f'<uiConfig>\r\n<applicationInfo name="CorelDRAW" version="27"/>'
                '<states><state name="frame"><container guidRef="original"/></state></states>'
                f'<commandBars><commandBarData guid="{STANDARD_BAR}"><toolbar>'
                '<item guidRef="existing"/></toolbar></commandBarData></commandBars>'
                '<items><itemData guid="existing" caption="Original &amp; unchanged"/></items>'
                '</uiConfig>').encode()

    def test_only_two_insertions(self):
        xml = self.xml()
        modified = add_button(xml)
        reference, definition = additions('\r\n')
        self.assertEqual(modified.replace(reference, b'', 1).replace(definition, b'', 1), xml)
        self.assertEqual(modified.count(b'dynamicCommand="DirectEnpack"'), 1)
        root = ET.fromstring(modified)
        self.assertEqual(root.find(f'./commandBars/commandBarData/toolbar/item[@guidRef="{BUTTON_ID}"]').get('guidRef'), BUTTON_ID)
        self.assertEqual(ET.tostring(root.find('states')), ET.tostring(ET.fromstring(xml).find('states')))

    def test_missing_items_section_is_created_without_rewriting_existing_xml(self):
        xml = self.xml()
        start, end = xml.index(b'<items>'), xml.index(b'</items>') + len(b'</items>')
        xml = xml[:start] + xml[end:]
        addon = b'<Addons><new_element installFile="C:\\Corel\\userdraw.xslt"/></Addons>'
        xml = xml.replace(b'</uiConfig>', addon + b'</uiConfig>')
        modified = add_button(xml)
        reference, definition = insertion_fragments('\r\n', True)
        self.assertEqual(modified.replace(reference, b'', 1).replace(definition, b'', 1), xml)
        self.assertIn(addon, modified)
        root = ET.fromstring(modified)
        self.assertEqual(len(root.findall('items')), 1)
        self.assertEqual(len(root.findall('./items/itemData')), 1)
        with self.assertRaises(ValueError):
            add_button(modified)

    def test_missing_items_with_lf_export(self):
        xml = self.xml()
        start, end = xml.index(b'<items>'), xml.index(b'</items>') + len(b'</items>')
        xml = (xml[:start] + xml[end:]).replace(b'\r\n', b'\n')
        modified = add_button(xml)
        reference, definition = insertion_fragments('\n', True)
        self.assertEqual(modified.replace(reference, b'', 1).replace(definition, b'', 1), xml)

    def test_nested_or_duplicate_items_sections_are_rejected(self):
        xml = self.xml()
        cases = [xml.replace(b'<items>', b'<items></items><items>'),
                 xml.replace(b'<items>', b'<container><items>').replace(b'</items>', b'</items></container>')]
        for case in cases:
            with self.assertRaises(ValueError):
                add_button(case)

    def test_refuses_duplicate_command(self):
        with self.assertRaises(ValueError):
            add_button(add_button(self.xml()))

    def test_refuses_missing_or_ambiguous_toolbar(self):
        for xml in (self.xml().replace(STANDARD_BAR.encode(), b'missing'),
                    self.xml().replace(b'</commandBars>',
                        f'<commandBarData guid="{STANDARD_BAR}"><toolbar></toolbar></commandBarData></commandBars>'.encode())):
            with self.assertRaises(ValueError):
                add_button(xml)

    def test_refuses_other_corel_version(self):
        with self.assertRaises(ValueError):
            add_button(self.xml().replace(b'version="27"', b'version="26"'))

    def test_icon_pixels_are_unchanged(self):
        original = (ROOT / 'upstream/icon.ico').read_bytes()
        normalized = rgba_icon(original)
        self.assertEqual(len(normalized), 1150)
        self.assertEqual(struct.unpack_from('<H', normalized, 12)[0], 32)
        bgra = normalized[22 + 40:22 + 40 + 1024]
        self.assertEqual(bgra, b''.join(original_pixels(original)))
        # AND mask agrees with alpha, including zeroed scanline padding.
        mask = normalized[22 + 40 + 1024:]
        for i, pixel in enumerate(original_pixels(original)):
            y, x = divmod(i, 16)
            self.assertEqual((mask[y * 4 + x // 8] >> (7 - x % 8)) & 1, int(pixel[3] == 0))

    def test_archive_copy_preserves_settings_and_original_file(self):
        with tempfile.TemporaryDirectory() as d:
            source, output = Path(d) / 'source.cdws', Path(d) / 'output.cdws'
            with zipfile.ZipFile(source, 'w') as z:
                z.writestr(XML_PATH, self.xml())
                z.writestr('content/settings.ini', b'untouched-settings')
                z.writestr('META-INF/metadata.xml', b'untouched-metadata')
            before = source.read_bytes()
            manifest = create_workspace(source, output)
            self.assertEqual(source.read_bytes(), before)
            with zipfile.ZipFile(output) as z:
                self.assertEqual(z.read('content/settings.ini'), b'untouched-settings')
                self.assertEqual(z.read('META-INF/metadata.xml'), b'untouched-metadata')
                self.assertIn(ICON_PATH, z.namelist())
                self.assertEqual(len(z.namelist()), 4)
            self.assertEqual(manifest['unchanged_members'], 2)
            with self.assertRaises(ValueError):
                create_workspace(source, source)
            with self.assertRaises(ValueError):
                create_workspace(source, output)

    def test_delivered_files_match_recorded_original_members(self):
        manifests = json.loads((ROOT / 'docs/clean-workspace-manifest.json').read_text())
        for m in manifests:
            with self.subTest(file=m['output']), zipfile.ZipFile(ROOT / 'deliverables' / m['output']) as z:
                self.assertEqual(hashlib.sha256((ROOT / 'deliverables' / m['output']).read_bytes()).hexdigest(), m['output_sha256'])
                self.assertEqual(set(z.namelist()) - set(m['source_members']), {ICON_PATH})
                for name, expected in m['source_members'].items():
                    data = z.read(name)
                    if name == XML_PATH:
                        reference, definition = additions('\r\n' if b'\r\n' in data else '\n')
                        self.assertEqual(data.count(reference), 1)
                        self.assertEqual(data.count(definition), 1)
                        data = data.replace(reference, b'', 1).replace(definition, b'', 1)
                    self.assertEqual(hashlib.sha256(data).hexdigest(), expected['sha256'])
                    info = z.getinfo(name)
                    for field in ('compress_type', 'external_attr'):
                        self.assertEqual(getattr(info, field), expected[field])
                    self.assertEqual(list(info.date_time), expected['date_time'])


if __name__ == '__main__':
    unittest.main()

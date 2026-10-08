#!/usr/bin/env python3
"""Verify the actual New_export deliverable and original-source bundle offline."""
import hashlib
import io
import json
import subprocess
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from create_workspace import ROOT, BUTTON_ID, ICON_ID, ICON_PATH, STANDARD_BAR, XML_PATH, insertion_fragments
from package_new_export import EXPECTED_CPG_SHA256


class NewExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / 'docs/new-export-manifest.json').read_text())
        cls.path = ROOT / 'deliverables' / cls.manifest['output']

    def test_all_original_content_preserved(self):
        self.assertTrue(self.manifest['items_container_added'])
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), self.manifest['output_sha256'])
        with zipfile.ZipFile(self.path) as z:
            self.assertIsNone(z.testzip())
            self.assertEqual(set(z.namelist()) - set(self.manifest['source_members']), {ICON_PATH})
            for name, original in self.manifest['source_members'].items():
                data = z.read(name)
                if name == XML_PATH:
                    reference, definition = insertion_fragments('\r\n', True)
                    self.assertEqual(data.count(reference), 1)
                    self.assertEqual(data.count(definition), 1)
                    data = data.replace(reference, b'', 1).replace(definition, b'', 1)
                self.assertEqual(hashlib.sha256(data).hexdigest(), original['sha256'], name)
                info = z.getinfo(name)
                self.assertEqual(list(info.date_time), original['date_time'])
                self.assertEqual(info.compress_type, original['compress_type'])
                self.assertEqual(info.external_attr, original['external_attr'])

    def test_button_command_icon_and_export_selection_are_linked(self):
        with zipfile.ZipFile(self.path) as z:
            root = ET.fromstring(z.read(XML_PATH))
            items = root.findall('./items/itemData')
            self.assertEqual(len(items), 1)
            self.assertEqual(items[0].get('guid'), BUTTON_ID)
            self.assertEqual(items[0].get('dynamicCommand'), 'DirectEnpack')
            self.assertEqual(items[0].get('dynamicCategory'), 'ab489730-8791-45d2-a825-b78bbe0d6a5d')
            self.assertEqual(items[0].get('icon'), 'guid://' + ICON_ID)
            self.assertTrue(z.read(ICON_PATH).startswith(b'\0\0\1\0'))
            refs = root.findall(f'./commandBars/commandBarData[@guid="{STANDARD_BAR}"]/toolbar/item[@guidRef="{BUTTON_ID}"]')
            self.assertEqual(len(refs), 1)
            self.assertEqual(len(root.findall(f'.//item[@guidRef="{BUTTON_ID}"]')), 1)
            export = ET.fromstring(z.read('content/exportsettings.xml'))
            self.assertEqual(export.find(f'./toolbars/toolbar[@guid="{STANDARD_BAR}"]').get('selected'), 'true')
            self.assertFalse(any(name.lower().endswith(('.cpg', '.asm', '.dll', '.gms')) for name in z.namelist()))

    def test_existing_addons_are_not_replaced_by_a_fake_cpg_installer(self):
        with zipfile.ZipFile(self.path) as z:
            root = ET.fromstring(z.read(XML_PATH))
            addons = root.find('Addons')
            self.assertEqual(len(addons), 3)
            self.assertEqual({n.get('installFile').split('\\')[-1] for n in addons},
                             {'userdesigner.xslt', 'userdraw.xslt', 'userpp.xslt'})
            self.assertTrue(all('technical suite' in n.get('installFile') for n in addons))

    def test_bundle_contains_original_binary_and_exact_source_blobs(self):
        with zipfile.ZipFile(ROOT / 'deliverables/New_export-DirectEnpack.zip') as z:
            self.assertIsNone(z.testzip())
            self.assertEqual(z.read(self.manifest['output']), self.path.read_bytes())
            self.assertEqual(hashlib.sha256(z.read('plugin/DirectEnpackx64.cpg')).hexdigest(), EXPECTED_CPG_SHA256)
            components = json.loads(z.read('COMPONENTS.json'))
            self.assertFalse(components['cpg_rebuilt_for_this_bundle'])
            self.assertFalse(components['runtime_tested_in_coreldraw'])
            self.assertEqual(len(components['source_files']), 12)
            for name, expected in components['source_files'].items():
                packed = z.read('source/' + name)
                self.assertEqual(hashlib.sha256(packed).hexdigest(), expected)
                # Git blobs, not Windows checkout newline conversions.
                blob = subprocess.check_output(['git', 'show', 'HEAD:upstream/' + name], cwd=ROOT)
                self.assertEqual(packed, blob, name)
            resource = z.read('source/Resources.inc').decode('cp1251')
            self.assertRegex(resource, r"strDirectEnpack\s+du\s+'DirectEnpack',0")
            for line in z.read('SHA256SUMS.txt').decode().splitlines():
                digest, name = line.split('  ', 1)
                self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(), digest, name)
            with zipfile.ZipFile(io.BytesIO(z.read(self.manifest['output']))) as workspace:
                self.assertFalse(any(n.lower().endswith('.cpg') for n in workspace.namelist()))


if __name__ == '__main__':
    unittest.main()

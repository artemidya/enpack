#!/usr/bin/env python3
"""SmartDepart workspace, source, resource and package regression tests."""
import hashlib
import io
import json
import struct
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from PIL import Image
import pefile
from smartdepart_workspace import (ROOT, VENDOR, UI_IDS, ICON_IDS, source_ui, fragments, icon_bytes, original_rgba,
                                  integrate_xml, STANDARD_BAR, XML_PATH, DIRECT_BUTTON)


class SmartDepartTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT/'docs/smartdepart-workspace-manifest.json').read_text())
        cls.base = ROOT/'deliverables'/cls.manifest['source']
        cls.output = ROOT/'deliverables'/cls.manifest['output']

    def test_source_geometry_dispatch_and_interfaces_unchanged(self):
        original = (VENDOR/'x64/SmartDepart.asm').read_text('cp1251')
        adapted = (ROOT/'src/smartdepart/x64/SmartDepart.asm').read_text('cp1251')
        self.assertEqual(original[:original.index('proc OnLoad this')],
                         adapted[:adapted.index("include 'Lifecycle27.inc'")])
        marker = ';;;;;;;;;;;;;;;ICUIDataSourceFactory'
        self.assertEqual(original[original.index(marker):], adapted[adapted.index(marker):])
        self.assertEqual((VENDOR/'x64/CorelDraw.inc').read_bytes(),
                         (ROOT/'src/smartdepart/x64/CorelDraw.inc').read_bytes())

    def test_all_working_directenpack_workspace_content_is_preserved(self):
        m = self.manifest
        self.assertEqual(hashlib.sha256(self.base.read_bytes()).hexdigest(), m['source_sha256'])
        self.assertEqual(hashlib.sha256(self.output.read_bytes()).hexdigest(), m['output_sha256'])
        with zipfile.ZipFile(self.base) as base, zipfile.ZipFile(self.output) as out:
            self.assertIsNone(out.testzip())
            self.assertEqual(set(out.namelist()) - set(base.namelist()), set(m['added_icons']))
            for name in base.namelist():
                data = out.read(name)
                if name == XML_PATH:
                    for insertion in fragments():
                        self.assertEqual(data.count(insertion), 1)
                        data = data.replace(insertion, b'', 1)
                self.assertEqual(data, base.read(name), name)
                self.assertEqual(hashlib.sha256(data).hexdigest(), m['source_members'][name])
                for field in ('external_attr','date_time','create_system','compress_type','comment','extra'):
                    self.assertEqual(getattr(base.getinfo(name), field), getattr(out.getinfo(name), field))

    def test_all_four_methods_and_tolerance_keep_original_bindings(self):
        definitions, bar = source_ui()
        for i in range(4):
            self.assertEqual(definitions[i+1].get('onInvoke'), f'*Bind(DataSource=SmartDepart;Path={i})')
        self.assertEqual(definitions[0].get('enable'), '*Or(*Bind(DataSource=WDocCommandsDS;Path=CanBreakApart),*Bind(DataSource=SelectionInfoDatasource;Path=IsValidCombine))')
        slider = definitions[-1]
        self.assertEqual(slider.get('value'), '*Bind(DataSource=SmartDepart;Path=4;BindType=TwoWay)')
        self.assertEqual([slider.get(k) for k in ['rangeMin','rangeMax','increment','numDecimalPlaces']], ['0.01','10','0.01','2'])
        self.assertEqual(definitions[0].get('flyoutBarRef'), bar.get('guid'))

    def test_only_one_flyout_and_existing_directenpack_still_present(self):
        with zipfile.ZipFile(self.output) as z: root = ET.fromstring(z.read(XML_PATH))
        direct = root.find(f'./items/itemData[@guid="{DIRECT_BUTTON}"]')
        self.assertEqual(direct.get('dynamicCommand'), 'DirectEnpack')
        for guid in UI_IDS.values():
            self.assertEqual(len([n for n in root.iter() if n.get('guid') == guid]), 1)
        refs = root.findall(f'./commandBars/commandBarData[@guid="{STANDARD_BAR}"]/toolbar/item')
        self.assertEqual(sum(n.get('guidRef') == UI_IDS['SmartDepart'] for n in refs), 1)
        self.assertEqual(sum(n.get('guidRef') == DIRECT_BUTTON for n in refs), 1)
        self.assertFalse(any(n.get('dynamicCommand') == 'SmartDepart' for n in root.iter('itemData')))

    def test_icons_preserve_rgba_pixels(self):
        with zipfile.ZipFile(self.output) as z:
            for i in range(1,5):
                original = original_rgba(i)
                data = z.read(f'content/icons/{ICON_IDS[f"SmartDepart_{i}"]}.ico')
                self.assertEqual(data, icon_bytes(i))
                self.assertEqual(struct.unpack_from('<H',data,12)[0],32)
                with Image.open(io.BytesIO(data)) as actual:
                    rgba = actual.convert('RGBA')
                    self.assertEqual(rgba.tobytes(), original.tobytes())
                    # Independent golden counts catch lost PNG tRNS/solid squares.
                    alpha = rgba.getchannel('A').tobytes()
                    self.assertEqual(alpha.count(b'\xff'), [92,55,39,40][i-1])
                    self.assertEqual(set(alpha), {0,255})

    def test_duplicate_or_missing_base_is_rejected(self):
        with zipfile.ZipFile(self.output) as z:
            with self.assertRaises(ValueError): integrate_xml(z.read(XML_PATH))
        with zipfile.ZipFile(self.base) as z:
            with self.assertRaises(ValueError):
                integrate_xml(z.read(XML_PATH).replace(b'dynamicCommand="DirectEnpack"',b'dynamicCommand="Other"'))

    def test_binary_is_x64_with_export_and_four_icon_resources(self):
        pe = pefile.PE(str(ROOT/'deliverables/SmartDepart.cpg'))
        self.assertEqual(pe.FILE_HEADER.Machine, 0x8664)
        self.assertTrue(pe.FILE_HEADER.Characteristics & 0x2000)
        self.assertEqual([s.name for s in pe.DIRECTORY_ENTRY_EXPORT.symbols], [b'AttachPlugin'])
        types = {e.id: e for e in pe.DIRECTORY_ENTRY_RESOURCE.entries}
        self.assertEqual({e.id for e in types[3].directory.entries}, {1,2,3,4})
        self.assertEqual({e.id for e in types[14].directory.entries}, {1,2,3,4})
        pe.close()

    def test_package_has_no_directenpack_replacement_or_active_xslt(self):
        with zipfile.ZipFile(ROOT/'deliverables/SmartDepart-27.zip') as z:
            self.assertIsNone(z.testzip())
            self.assertEqual([n for n in z.namelist() if n.startswith('plugin/')], ['plugin/SmartDepart.cpg'])
            self.assertEqual(z.read('plugin/SmartDepart.cpg'), (ROOT/'deliverables/SmartDepart.cpg').read_bytes())
            self.assertEqual(z.read(self.manifest['output']), self.output.read_bytes())
            for line in z.read('SHA256SUMS.txt').decode().splitlines():
                h,name = line.split('  ',1)
                self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(), h)
            for folder,label in [(VENDOR,'source-original'),(ROOT/'src/smartdepart','source-adapted')]:
                for file in folder.rglob('*'):
                    if file.is_file():
                        # Decode text for cross-platform git checkout newline conversions.
                        data = z.read(label+'/'+file.relative_to(folder).as_posix())
                        raw = file.read_bytes()
                        if file.suffix in ('.asm','.inc','.md','.xslt','.xml') or file.name in ('LICENSE','.gitattributes'):
                            self.assertEqual(data.replace(b'\r\n',b'\n'),raw.replace(b'\r\n',b'\n'))
                        else: self.assertEqual(data,raw)


if __name__ == '__main__': unittest.main()

#!/usr/bin/env python3
"""Integrate original SmartDepart data-source UI into the working DirectEnpack CDWS.

Only three XML insertions and four embedded icons; no XSLT installation/reset.
Requires Pillow for faithful conversion of upstream PNG-in-ICO to 32-bit DIB ICO.
"""
import argparse
import copy
import hashlib
import io
import json
import re
import struct
import uuid
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from PIL import Image
from create_workspace import ROOT, STANDARD_BAR, XML_PATH, BUTTON_ID as DIRECT_BUTTON
from fix_workspace_icon import parse_xml, MAX_UNCOMPRESSED

VENDOR = ROOT / 'vendor/SmartDepart'
NS = {'xsl': 'http://www.w3.org/1999/XSL/Transform'}
UI_IDS = {name: str(uuid.uuid5(uuid.NAMESPACE_URL, 'https://github.com/artemidya/enpack/smartdepart/ui-v1/' + name))
          for name in ['SmartDepart', 'SmartDepart_bar'] + ['SmartDepart' + str(i) for i in range(1, 7)]}
ICON_IDS = {f'SmartDepart_{i}': str(uuid.uuid5(uuid.NAMESPACE_URL, 'https://github.com/artemidya/enpack/smartdepart/icon-v1/' + str(i)))
            for i in range(1, 5)}


def source_ui():
    root = ET.fromstring((VENDOR / 'AppUI.xslt').read_bytes())
    items = root.find("xsl:template[@match='uiConfig/items']/xsl:copy", NS)
    bars = root.find("xsl:template[@match='uiConfig/commandBars']/xsl:copy", NS)
    definitions = [copy.deepcopy(x) for x in items if x.tag == 'itemData']
    bar = copy.deepcopy(next(x for x in bars if x.tag == 'commandBarData'))
    assert len(definitions) == 7
    for node in definitions + [bar]:
        for child in node.iter():
            for key in ('guid', 'guidRef', 'flyoutBarRef'):
                value = child.get(key)
                if value in UI_IDS: child.set(key, UI_IDS[value])
            icon = child.get('icon', '')
            if icon.startswith('guid://') and icon[7:] in ICON_IDS:
                child.set('icon', 'guid://' + ICON_IDS[icon[7:]])
    definitions[0].set('userCaption', 'SmartDepart')
    return definitions, bar


def fragments():
    definitions, bar = source_ui()
    for node in definitions + [bar]: node.tail = None
    reference = f'\r\n<item guidRef="{UI_IDS["SmartDepart"]}"/>'.encode()
    items = b'\r\n' + b'\r\n'.join(ET.tostring(n, encoding='utf-8') for n in definitions) + b'\r\n'
    menu = b'\r\n' + ET.tostring(bar, encoding='utf-8') + b'\r\n'
    return reference, items, menu


def original_rgba(index):
    # These ICOs contain indexed PNGs with tRNS transparency. Opening the ICO
    # wrapper with Pillow loses that PNG metadata and yields a black square.
    # Decode the actual embedded PNG, preserving its transparent palette entry.
    data = (VENDOR / f'{index}.ico').read_bytes()
    if struct.unpack_from('<HHH', data) != (0, 1, 1):
        raise ValueError('Expected the original single-image ICO')
    size, offset = struct.unpack_from('<II', data, 14)
    if offset < 22 or offset + size > len(data): raise ValueError('Invalid ICO entry')
    payload = data[offset:offset+size]
    if not payload.startswith(b'\x89PNG\r\n\x1a\n'): raise ValueError('Expected embedded PNG')
    with Image.open(io.BytesIO(payload)) as original:
        rgba = original.convert('RGBA')
        if rgba.size != (16, 16): raise ValueError('Expected 16x16 icon')
        return rgba


def icon_bytes(index):
    rgba = original_rgba(index)
    buffer = io.BytesIO()
    rgba.save(buffer, format='ICO', sizes=[(16, 16)], bitmap_format='bmp')
    data = buffer.getvalue()
    with Image.open(io.BytesIO(data)) as decoded:
        assert decoded.convert('RGBA').tobytes() == rgba.tobytes()
    return data


def integrate_xml(xml):
    root = parse_xml(xml)
    if root.find('applicationInfo').get('version') != '27':
        raise ValueError('Expected CorelDRAW 27')
    direct = root.find(f'./items/itemData[@guid="{DIRECT_BUTTON}"]')
    if direct is None or direct.get('dynamicCommand') != 'DirectEnpack':
        raise ValueError('Use the known-working DirectEnpack workspace, not a different profile')
    if b'DataSource=SmartDepart' in xml or any(n.get('guid') in UI_IDS.values() for n in root.iter()):
        raise ValueError('SmartDepart already present; refusing duplicate integration')
    if xml.count(b'</items>') != 1 or xml.count(b'</commandBars>') != 1:
        raise ValueError('Ambiguous or missing XML containers')
    matches = [m for m in re.finditer(rb'<commandBarData\b[^>]*>.*?</commandBarData>', xml, re.S)
               if ET.fromstring(m.group()).get('guid') == STANDARD_BAR]
    if len(matches) != 1 or matches[0].group().count(b'</toolbar>') != 1:
        raise ValueError('Expected one existing Standard toolbar')
    reference, items, menu = fragments()
    at = matches[0].start() + matches[0].group().index(b'</toolbar>')
    modified = xml[:at] + reference + xml[at:]
    modified = modified.replace(b'</items>', items + b'</items>', 1)
    modified = modified.replace(b'</commandBars>', menu + b'</commandBars>', 1)
    parse_xml(modified)
    restored = modified
    for part in fragments():
        if restored.count(part) != 1: raise ValueError('Non-unique insertion')
        restored = restored.replace(part, b'', 1)
    if restored != xml: raise ValueError('Source XML preservation failed')
    return modified


def create(source, output):
    source, output = Path(source), Path(output)
    if source.resolve() == output.resolve() or output.exists():
        raise ValueError('Output must be a new file')
    with zipfile.ZipFile(source) as original:
        entries = original.infolist()
        if len(entries) > 10000 or len(entries) != len(set(original.namelist())):
            raise ValueError('Invalid or duplicate ZIP members')
        if sum(x.file_size for x in entries) > MAX_UNCOMPRESSED: raise ValueError('Archive too large')
        modified = integrate_xml(original.read(XML_PATH))
        icons = {f'content/icons/{ICON_IDS[f"SmartDepart_{i}"]}.ico': icon_bytes(i) for i in range(1, 5)}
        if set(icons) & set(original.namelist()): raise ValueError('Icon collision')
        output.parent.mkdir(parents=True, exist_ok=True)
        stream = output.open('xb')
        try:
            with stream, zipfile.ZipFile(stream, 'w') as target:
                target.comment = original.comment
                for entry in entries:
                    info = copy.copy(entry)
                    target.writestr(info, modified if entry.filename == XML_PATH else original.read(entry))
                    info.external_attr = entry.external_attr
                for name, data in icons.items():
                    info = zipfile.ZipInfo(name, (2026, 10, 8, 0, 0, 0))
                    info.compress_type = zipfile.ZIP_DEFLATED
                    info.create_system = original.getinfo(XML_PATH).create_system
                    target.writestr(info, data)
                    info.external_attr = original.getinfo(XML_PATH).external_attr
        except BaseException:
            output.unlink(missing_ok=True)
            raise
        manifest = {
            'source': source.name, 'output': output.name,
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'output_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
            'source_members': {n: hashlib.sha256(original.read(n)).hexdigest() for n in original.namelist()},
            'added_icons': {n: hashlib.sha256(v).hexdigest() for n, v in icons.items()},
            'changes': 'three XML insertions; DirectEnpack, menus, settings and Addons preserved',
            'datasource': 'SmartDepart', 'method_paths': ['0','1','2','3'], 'tolerance_path': '4',
            'runtime_tested_in_coreldraw': False,
        }
    with zipfile.ZipFile(output) as z: assert z.testzip() is None
    return manifest


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('output', type=Path)
    a = p.parse_args()
    print(json.dumps(create(a.source, a.output), ensure_ascii=False, indent=2))

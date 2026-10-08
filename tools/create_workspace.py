#!/usr/bin/env python3
"""Add ONE DirectEnpack button to a clean CorelDRAW 27 workspace copy.

Never merges workspaces. No existing setting/menu/state/metadata is rewritten.
Preserves all original XML bytes, adding only a button reference and definition.
"""
import argparse
import copy
import hashlib
import json
import re
import struct
import uuid
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from fix_workspace_icon import parse_xml, validate_icon, PLUGIN_CATEGORY, MAX_UNCOMPRESSED

STANDARD_BAR = 'c2b44f69-6dec-444e-a37e-5dbf7ff43dae'
BUTTON_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, 'https://github.com/artemidya/enpack/directenpack-clean-button-v1'))
ICON_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, 'https://github.com/artemidya/enpack/directenpack-original-rgba-v1'))
ICON_PATH = f'content/icons/{ICON_ID}.ico'
XML_PATH = 'content/workspace.xml'
ROOT = Path(__file__).resolve().parents[1]


def original_pixels(data):
    """Decode this project's 16x16 1-bit ICO, rejecting other formats."""
    validate_icon(data)
    if struct.unpack_from('<HHH', data) != (0, 1, 1):
        raise ValueError('Expected the original single-image ICO')
    width, height, colors, reserved, planes, bits, size, offset = struct.unpack_from('<BBBBHHII', data, 6)
    header = struct.unpack_from('<IiiHHIIiiII', data, offset)
    if (width, height, colors, planes, bits) != (16, 16, 2, 1, 1) or header[:6] != (40, 16, 32, 1, 1, 0):
        raise ValueError('Unsupported original ICO format')
    palette = [data[offset + 40 + i * 4:offset + 44 + i * 4] for i in range(2)]
    xor = offset + 48
    mask = xor + 64
    if mask + 64 > offset + size:
        raise ValueError('Truncated bitmap')
    pixels = []
    for y in range(16):
        for x in range(16):
            bit = 7 - x % 8
            color = palette[(data[xor + y * 4 + x // 8] >> bit) & 1]
            transparent = (data[mask + y * 4 + x // 8] >> bit) & 1
            if transparent and any(color[:3]):
                raise ValueError('XOR/inverted transparency cannot be represented as RGBA')
            pixels.append(bytes(color[:3]) + bytes([0 if transparent else 255]))
    return pixels  # DIB bottom-up BGRA order


def rgba_icon(original):
    pixels = original_pixels(original)
    mask = bytearray(64)
    for index, pixel in enumerate(pixels):
        y, x = divmod(index, 16)
        if pixel[3] == 0:
            mask[y * 4 + x // 8] |= 1 << (7 - x % 8)
    image = b''.join(pixels)
    dib = struct.pack('<IiiHHIIiiII', 40, 16, 32, 1, 32, 0, len(image) + len(mask), 0, 0, 0, 0)
    payload = dib + image + mask
    result = struct.pack('<HHHBBBBHHII', 0, 1, 1, 16, 16, 0, 0, 1, 32, len(payload), 22) + payload
    validate_icon(result)
    return result


def additions(newline):
    reference = (newline + f'        <item guidRef="{BUTTON_ID}"></item>').encode()
    definition = (newline + f'    <itemData guid="{BUTTON_ID}" dynamicCommand="DirectEnpack" '
                  f'dynamicCategory="{PLUGIN_CATEGORY}" userCaption="Прямоугольный раскрой" '
                  f'icon="guid://{ICON_ID}"></itemData>' + newline).encode('utf-8')
    return reference, definition


def insertion_fragments(newline, add_items_container=False):
    reference, definition = additions(newline)
    if add_items_container:
        # Some genuine exports (including New_export.cdws) have no custom
        # commands yet, hence no <items> section at all. Add it, never borrow
        # a section from another workspace or rewrite the existing root.
        definition = newline.encode() + b'  <items>' + definition + b'  </items>' + newline.encode()
    return reference, definition


def add_button(xml):
    root = parse_xml(xml)
    if root.tag != 'uiConfig':
        raise ValueError('Expected a uiConfig root')
    info = root.find('applicationInfo')
    if info is None or info.get('name') != 'CorelDRAW' or info.get('version') != '27':
        raise ValueError('Expected a CorelDRAW 27 workspace')
    if any(n.get('dynamicCommand') == 'DirectEnpack' for n in root.iter('itemData')):
        raise ValueError('DirectEnpack already present; refusing to duplicate/merge')
    if any(n.get('guid') in (BUTTON_ID, ICON_ID) for n in root.iter()):
        raise ValueError('Generated ID collision')
    items = root.findall('items')
    if len(items) > 1:
        raise ValueError('Ambiguous items containers')
    add_items_container = not items
    anchor = b'</uiConfig>' if add_items_container else b'</items>'
    if xml.count(anchor) != 1 or (add_items_container and any(n.tag == 'items' for n in root.iter())):
        raise ValueError('Ambiguous, nested or self-closing items/root container')
    reference, definition = insertion_fragments('\r\n' if b'\r\n' in xml else '\n', add_items_container)
    matches = []
    for match in re.finditer(rb'<commandBarData\b[^>]*>.*?</commandBarData>', xml, re.S):
        element = ET.fromstring(match.group())
        if element.get('guid') == STANDARD_BAR:
            if len(element.findall('toolbar')) != 1 or match.group().count(b'</toolbar>') != 1:
                raise ValueError('Expected one existing Standard toolbar')
            matches.append(match)
    if len(matches) != 1:
        raise ValueError('Ambiguous or missing Standard toolbar')
    match = matches[0]
    index = match.start() + match.group().index(b'</toolbar>')
    result = xml[:index] + reference + xml[index:]
    result = result.replace(anchor, definition + anchor, 1)
    parsed = parse_xml(result)
    assert len(parsed.findall('items')) == 1
    assert len([n for n in parsed.iter('itemData') if n.get('dynamicCommand') == 'DirectEnpack']) == 1
    assert len([n for n in parsed.iter('item') if n.get('guidRef') == BUTTON_ID]) == 1
    if result.replace(reference, b'', 1).replace(definition, b'', 1) != xml:
        raise ValueError('Original XML preservation check failed')
    return result


def create_workspace(source, output):
    source, output = Path(source), Path(output)
    if source.resolve() == output.resolve() or output.exists():
        raise ValueError('Output must be a NEW file, never the original')
    icon = rgba_icon((ROOT / 'upstream/icon.ico').read_bytes())
    with zipfile.ZipFile(source) as original:
        entries = original.infolist()
        names = original.namelist()
        if len(entries) > 10000 or len(names) != len(set(names)):
            raise ValueError('Too many or duplicate ZIP members')
        if sum(x.file_size for x in entries) > MAX_UNCOMPRESSED:
            raise ValueError('Workspace too large')
        if ICON_PATH in names:
            raise ValueError('Icon already exists')
        xml = original.read(XML_PATH)
        modified = add_button(xml)
        output.parent.mkdir(parents=True, exist_ok=True)
        stream = output.open('xb')
        try:
            with stream, zipfile.ZipFile(stream, 'w') as target:
                target.comment = original.comment
                for entry in entries:
                    data = modified if entry.filename == XML_PATH else original.read(entry)
                    info = copy.copy(entry)
                    target.writestr(info, data)
                    # zipfile replaces a valid zero external_attr with Unix 0600.
                    # Restore it before writing the central directory on close.
                    info.external_attr = entry.external_attr
                icon_info = zipfile.ZipInfo(ICON_PATH, (2026, 10, 8, 0, 0, 0))
                icon_info.compress_type = zipfile.ZIP_DEFLATED
                icon_info.create_system = original.getinfo(XML_PATH).create_system
                target.writestr(icon_info, icon)
                icon_info.external_attr = original.getinfo(XML_PATH).external_attr
        except BaseException:
            output.unlink(missing_ok=True)
            raise
    # Verify every original member, not merely XML parseability.
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(output) as target:
        assert target.testzip() is None
        assert set(target.namelist()) - set(original.namelist()) == {ICON_PATH}
        assert all(original.read(n) == target.read(n) for n in original.namelist() if n != XML_PATH)
        source_members = {entry.filename: {
            'sha256': hashlib.sha256(original.read(entry)).hexdigest(),
            'date_time': list(entry.date_time), 'compress_type': entry.compress_type,
            'external_attr': entry.external_attr
        } for entry in original.infolist()}
    return {'source': source.name, 'output': output.name,
            'source_members': source_members,
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'output_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
            'button_id': BUTTON_ID, 'toolbar_id': STANDARD_BAR, 'icon_path': ICON_PATH,
            'original_members': len(entries), 'unchanged_members': len(entries) - 1,
            'items_container_added': parse_xml(xml).find('items') is None,
            'xml_change': 'two insertions only; removing them recovers original XML bytes',
            'icon': 'original 16x16 silhouette, normalized to 32-bit BGRA with alpha',
            'runtime_tested_in_coreldraw': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    print(json.dumps(create_workspace(args.source, args.output), ensure_ascii=False, indent=2))

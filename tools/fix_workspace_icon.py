#!/usr/bin/env python3
"""Embed the original DirectEnpack icon in a COPY of a CorelDRAW .cdws.

Does not install a CPG, run CorelDRAW, execute macros, or change the input.
Only matching plugin itemData icon attributes and one icon ZIP entry change.
All other decompressed archive members and XML bytes are preserved.
"""
import argparse
import copy
import hashlib
import re
import struct
import uuid
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

PLUGIN_CATEGORY = 'ab489730-8791-45d2-a825-b78bbe0d6a5d'
ICON_ID = str(uuid.uuid5(uuid.NAMESPACE_URL,
    'https://github.com/fersatgit/DirectEnpack/blob/fd88547ffb69fcd8f0bc84441bd589414f918f25/icon.ico'))
ICON_PATH = f'content/icons/{ICON_ID}.ico'
ICON_URI = f'guid://{ICON_ID}'
WORKSPACE_PATH = 'content/workspace.xml'
MAX_UNCOMPRESSED = 64 * 1024 * 1024


def is_target(element):
    return (element.tag == 'itemData'
            and element.get('dynamicCommand') == 'DirectEnpack'
            and element.get('dynamicCategory', '').lower() == PLUGIN_CATEGORY)


def parse_xml(data):
    # Corel's workspace uses plain UTF-8 XML, no entities/DTD required.
    if b'<!DOCTYPE' in data or b'<!ENTITY' in data:
        raise ValueError('DTD/entity declarations are not supported')
    data.decode('utf-8-sig')
    return ET.fromstring(data)


def validate_icon(data):
    if len(data) < 22:
        raise ValueError('Icon is too short')
    reserved, kind, count = struct.unpack_from('<HHH', data)
    if (reserved, kind) != (0, 1) or not 1 <= count <= 256:
        raise ValueError('Expected an ICO file')
    directory_end = 6 + count * 16
    if directory_end > len(data):
        raise ValueError('Truncated ICO directory')
    for index in range(count):
        size, offset = struct.unpack_from('<II', data, 6 + 16 * index + 8)
        if not size or offset < directory_end or offset + size > len(data):
            raise ValueError('Truncated/invalid ICO image')


def patch_xml(data):
    root = parse_xml(data)
    targets = [node for node in root.iter('itemData') if is_target(node)]
    if not targets:
        raise ValueError('No DirectEnpack plugin itemData entries found; nothing written')
    changed_guids = []

    def replace(match):
        tag = match.group()
        fragment = tag if tag.endswith(b'/>') else tag[:-1] + b'/>'
        node = ET.fromstring(fragment)
        if not is_target(node):
            return tag
        guid = node.get('guid')
        if not guid:
            raise ValueError('DirectEnpack itemData has no guid')
        changed_guids.append(guid)
        attribute = f'icon="{ICON_URI}"'.encode('ascii')
        if 'icon' in node.attrib:
            tag, count = re.subn(rb'\bicon\s*=\s*(?:"[^"]*"|\x27[^\x27]*\x27)', attribute, tag)
            if count != 1:
                raise ValueError('Ambiguous icon attribute')
            return tag
        close = -2 if tag.endswith(b'/>') else -1
        return tag[:close] + b' ' + attribute + tag[close:]

    patched = re.sub(rb'<itemData\b[^<>]*>', replace, data)
    new_root = parse_xml(patched)
    new_targets = [node for node in new_root.iter('itemData') if is_target(node)]
    if len(changed_guids) != len(targets) or len(new_targets) != len(targets):
        raise ValueError('Not all DirectEnpack entries could be patched')
    if any(node.get('icon') != ICON_URI for node in new_targets):
        raise ValueError('Icon reference verification failed')
    return patched, changed_guids


def fix_workspace(source, destination, icon):
    source, destination, icon = Path(source), Path(destination), Path(icon)
    if source.resolve() == destination.resolve():
        raise ValueError('Input and output must be different: keep the original workspace')
    if destination.exists():
        raise FileExistsError(f'Refusing to overwrite {destination}')
    icon_data = icon.read_bytes()
    validate_icon(icon_data)
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    with zipfile.ZipFile(source, 'r') as original:
        entries = original.infolist()
        names = [entry.filename for entry in entries]
        if len(entries) > 10000 or len(names) != len(set(names)):
            raise ValueError('Too many or duplicate ZIP members')
        if sum(entry.file_size for entry in entries) > MAX_UNCOMPRESSED:
            raise ValueError('Workspace exceeds the 64 MiB uncompressed limit')
        if WORKSPACE_PATH not in names:
            raise ValueError('No content/workspace.xml in archive')
        if ICON_PATH in names and original.read(ICON_PATH) != icon_data:
            raise ValueError('Icon ID already exists with different contents')
        patched_xml, guids = patch_xml(original.read(WORKSPACE_PATH))
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation: never overwrite the source or another result.
        stream = destination.open('xb')
        try:
            with stream, zipfile.ZipFile(stream, 'w') as result:
                result.comment = original.comment
                for entry in entries:
                    contents = patched_xml if entry.filename == WORKSPACE_PATH else original.read(entry)
                    result.writestr(copy.copy(entry), contents)
                if ICON_PATH not in names:
                    entry = zipfile.ZipInfo(ICON_PATH, date_time=(2026, 10, 8, 0, 0, 0))
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    result.writestr(entry, icon_data)
        except BaseException:
            destination.unlink(missing_ok=True)
            raise
    return {'source_sha256': source_hash,
            'output_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
            'icon_sha256': hashlib.sha256(icon_data).hexdigest(),
            'icon_path': ICON_PATH, 'item_guids': guids}


if __name__ == '__main__':
    import json
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='Original .cdws')
    parser.add_argument('output', type=Path, help='New .cdws; must not already exist')
    parser.add_argument('--icon', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'upstream/icon.ico')
    args = parser.parse_args()
    print(json.dumps(fix_workspace(args.input, args.output, args.icon), ensure_ascii=False, indent=2))

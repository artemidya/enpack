#!/usr/bin/env python3
"""Add only Bleeds to the delivered DirectEnpack + SmartDepart workspace."""
import copy,hashlib,json,re,uuid,zipfile
from pathlib import Path
from xml.etree import ElementTree as ET
from create_workspace import STANDARD_BAR,XML_PATH
from fix_workspace_icon import PLUGIN_CATEGORY,parse_xml,validate_icon
ROOT=Path(__file__).resolve().parents[1]
BUTTON=str(uuid.uuid5(uuid.NAMESPACE_URL,'https://github.com/artemidya/enpack/bleeds-button-v1'))
ICON=str(uuid.uuid5(uuid.NAMESPACE_URL,'https://github.com/artemidya/enpack/bleeds-upstream-bitmap-v1'))
ICON_PATH=f'content/icons/{ICON}.ico'
BASE=ROOT/'deliverables/New_export-DirectEnpack-SmartDepart.cdws'
OUTPUT=ROOT/'deliverables/New_export-DirectEnpack-SmartDepart-Bleeds.cdws'
def fragments():
 return (f'\n        <item guidRef="{BUTTON}"></item>'.encode(),
 f'\n    <itemData guid="{BUTTON}" dynamicCommand="Bleeds" dynamicCategory="{PLUGIN_CATEGORY}" userCaption="Bleeds — припуски" icon="guid://{ICON}"></itemData>\n'.encode())
def integrate(xml):
 root=parse_xml(xml)
 assert root.find('applicationInfo').get('version')=='27'
 if any(n.get('dynamicCommand')=='Bleeds' or n.get('guid') in (BUTTON,ICON) for n in root.iter()):raise ValueError('Bleeds already present')
 assert xml.count(b'</items>')==1
 matches=[m for m in re.finditer(rb'<commandBarData\b[^>]*>.*?</commandBarData>',xml,re.S) if ET.fromstring(m.group()).get('guid')==STANDARD_BAR]
 assert len(matches)==1 and matches[0].group().count(b'</toolbar>')==1
 a,b=fragments();i=matches[0].start()+matches[0].group().index(b'</toolbar>')
 result=(xml[:i]+a+xml[i:]).replace(b'</items>',b+b'</items>',1)
 assert result.replace(a,b'',1).replace(b,b'',1)==xml
 parse_xml(result);return result

def build():
 if OUTPUT.exists():raise ValueError('Refusing overwrite; explicitly remove generated output first')
 icon=(ROOT/'src/bleeds/icon.ico').read_bytes();validate_icon(icon)
 with zipfile.ZipFile(BASE) as old,zipfile.ZipFile(OUTPUT,'w') as new:
  new.comment=old.comment
  for entry in old.infolist():
   data=old.read(entry);data=integrate(data) if entry.filename==XML_PATH else data
   info=copy.copy(entry);new.writestr(info,data);info.external_attr=entry.external_attr
  info=zipfile.ZipInfo(ICON_PATH,(2026,10,8,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
  new.writestr(info,icon)
 with zipfile.ZipFile(BASE) as old,zipfile.ZipFile(OUTPUT) as new:
  members={n:hashlib.sha256(old.read(n)).hexdigest() for n in old.namelist()}
  assert new.testzip() is None
  assert set(new.namelist())-set(old.namelist())=={ICON_PATH}
  for n in old.namelist():
   data=new.read(n)
   if n==XML_PATH:
    for f in fragments():data=data.replace(f,b'',1)
   assert data==old.read(n)
 report=dict(source=BASE.name,output=OUTPUT.name,source_sha256=hashlib.sha256(BASE.read_bytes()).hexdigest(),output_sha256=hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),source_members=members,added_icon=ICON_PATH,button_id=BUTTON,toolbar_id=STANDARD_BAR)
 (ROOT/'docs/bleeds-workspace-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':build()

#!/usr/bin/env python3
"""Capture actual app views. Requires preinstalled pricing-v2 Debug build and audit OCR tool.
No network, purchase, App Store Connect or release-source edits are performed here.
"""
from pathlib import Path
import subprocess, time, json, sys
ROOT=Path(__file__).resolve().parents[2]
BUNDLE='Resumebuilder-IOS.ResumeBuilder-IOS-APP'
DEVICES={'iphone':'9E2E82B6-DC56-4162-846F-B96AE74867E7','ipad':'414996FA-6056-46FC-B08C-9CA1723C0857'}
VIEWS=[('01-tailor',[], 'Upload your'),('02-missing',['--smoke-diagnosis','--smoke-fit'],'What is holding'),('03-edits',['--smoke-diagnosis','--smoke-confirm'],'Add only if true'),('04-review',['--smoke-diagnosis'],'What changed')]
OCR=ROOT/'audit/aso-v3-t2/ocr'
records=[]
for device,udid in DEVICES.items():
 for name,args,expected in VIEWS:
  target=ROOT/'scripts/aso-v3/release-captures'/device/f'{name}.png'
  # Existing confirmed Home and match captures may be reused only after OCR.
  if target.exists() and '--fresh' not in sys.argv:
   found=subprocess.run([str(OCR),str(target)],capture_output=True,text=True,timeout=90).stdout
   if expected.lower() in found.lower():
    print(device,name,'existing capture verified',flush=True)
    records.append({'device':device,'udid':udid,'file':str(target.relative_to(ROOT)),'text_check':expected});continue
  subprocess.run(['xcrun','simctl','terminate',udid,BUNDLE],capture_output=True,timeout=60)
  subprocess.run(['xcrun','simctl','launch',udid,BUNDLE,*args],check=True,timeout=90)
  for attempt in range(5):
   time.sleep(5)
   candidate=target.with_suffix('.candidate.png')
   subprocess.run(['xcrun','simctl','io',udid,'screenshot',str(candidate)],check=True,capture_output=True,timeout=60)
   found=subprocess.run([str(OCR),str(candidate)],capture_output=True,text=True,timeout=90).stdout
   if expected.lower() in found.lower():
    candidate.replace(target)
    records.append({'device':device,'udid':udid,'file':str(target.relative_to(ROOT)),'launch_args':args,'text_check':expected})
    print(device,name,'captured and verified',flush=True);break
  else: raise RuntimeError(f'{device} {name}: expected UI not rendered; refusing blank capture')
(ROOT/'audit/aso-v3-t2/capture-record.json').write_text(json.dumps(records,indent=2)+'\n')

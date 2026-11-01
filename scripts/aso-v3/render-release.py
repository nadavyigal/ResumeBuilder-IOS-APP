#!/usr/bin/env python3
"""Render local artwork with one isolated Chrome session, then verify every output."""
from pathlib import Path
from PIL import Image
import subprocess, os, tempfile, shutil, json, hashlib, time, urllib.request, signal
ROOT=Path(__file__).resolve().parents[2]
SLOTS=[('release-iphone-6.3-1206x2622',1206,2622),('release-iphone-6.5-1242x2688',1242,2688),('release-ipad-13-2064x2752',2064,2752)]
NAMES=['01-tailor.png','02-missing.png','03-edits.png','04-review.png']
AUDIT=ROOT/'audit/aso-v3-t2'
chrome=os.environ.get('CHROME_BIN','/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
stage=Path(tempfile.mkdtemp(prefix='release-render-',dir=AUDIT))
profile=stage/'chrome-profile'
renderer=AUDIT/'release-renderer'
subprocess.run(['swiftc','-parse-as-library',str(ROOT/'scripts/aso-v3/render-release.swift'),'-o',str(renderer)],check=True,timeout=120)
with (AUDIT/'release-browser.log').open('w') as log:
 browser=subprocess.Popen([chrome,f'--user-data-dir={profile}','--headless=new','--disable-gpu','--hide-scrollbars','--no-first-run','--no-default-browser-check','--disable-background-networking','--allow-file-access-from-files','--remote-debugging-port=0','about:blank'],stdout=log,stderr=log,start_new_session=True)
 try:
  for _ in range(180):
   if browser.poll() is not None:raise RuntimeError(f'Chrome exited: {browser.returncode}')
   if (profile/'DevToolsActivePort').exists():break
   time.sleep(.5)
  else:raise TimeoutError('Chrome did not start')
  port=(profile/'DevToolsActivePort').read_text().splitlines()[0]
  with urllib.request.urlopen(f'http://127.0.0.1:{port}/json/version',timeout=20) as response:
   (AUDIT/'render-browser-version.json').write_text(json.dumps(json.load(response),indent=2)+'\n')
  subprocess.run([str(renderer),port,str(ROOT/'scripts/aso-v3'),str(stage)],check=True,timeout=600)
  if browser.poll() is not None:raise RuntimeError('Chrome exited during rendering')
 finally:
  os.killpg(browser.pid,signal.SIGTERM)
  try:browser.wait(timeout=10)
  except subprocess.TimeoutExpired:os.killpg(browser.pid,signal.SIGKILL);browser.wait(timeout=10)
records=[]
# Validate the whole candidate before replacing any final slot files.
for slot,w,h in SLOTS:
 (stage/slot).mkdir()
 with Image.open(stage/(slot+'.png')) as grid:
  grid.load();assert grid.size==(w,h*4),(slot,grid.size)
  for index,name in enumerate(NAMES):
   grid.crop((0,index*h,w,(index+1)*h)).convert('RGB').save(stage/slot/name)
 assert sorted(p.name for p in (stage/slot).glob('*.png'))==NAMES
 for name in NAMES:
  p=stage/slot/name
  with Image.open(p) as im:
   im.load();assert im.size==(w,h),(p,im.size)
   im.convert('RGB').save(p)
for slot,w,h in SLOTS:
 dest=ROOT/'dist/app-store-screenshots/app-store-v3'/slot
 dest.mkdir(exist_ok=True)
 for name in NAMES:
  shutil.copyfile(stage/slot/name,dest/name)
  records.append({'slot':slot,'file':str((dest/name).relative_to(ROOT)),'size':[w,h],'mode':'RGB','sha256':hashlib.sha256((dest/name).read_bytes()).hexdigest()})
 print(slot,'PASS: four fresh opaque PNGs',flush=True)
(AUDIT/'release-outputs.json').write_text(json.dumps(records,indent=2)+'\n')
shutil.rmtree(profile,ignore_errors=True)

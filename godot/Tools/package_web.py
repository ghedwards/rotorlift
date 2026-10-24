"""Package an existing Godot Web export as a clean Pages site and upload ZIP."""
from pathlib import Path
import argparse, shutil, zipfile, json, hashlib, html
project=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,default=project/'builds/web')
parser.add_argument('--output',type=Path,default=project/'builds/site')
args=parser.parse_args()
source=args.source.resolve(); output=args.output.resolve()
if source==output or source in output.parents or output in source.parents:
 raise SystemExit('Source and output must be separate, non-nested directories')
required=['index.html','index.js','index.wasm','index.pck']
for name in required:
 if not (source/name).is_file() or (source/name).stat().st_size==0:raise SystemExit('Missing export: '+name)
if output.exists():
 raise SystemExit(f'Output already exists: {output}. Choose a new empty output directory.')
output.mkdir(parents=True)
for path in source.iterdir():
 if path.is_file() and path.suffix in {'.html','.js','.wasm','.pck','.png','.json','.svg'}:
  shutil.copy2(path,output/path.name)
(output/'.nojekyll').touch()
licenses=output/'licenses';licenses.mkdir()
for path in project.joinpath('Assets').rglob('*'):
 if path.is_file() and ('LICENSE' in path.name or 'COPYRIGHT' in path.name):
  shutil.copy2(path,licenses/path.name)
(output/'build-info.json').write_text(json.dumps({'engine':'Godot 4.7.2','threaded':False,'orientation':'landscape','controls':'WASD / arrows, Space; touch controls'},indent=2)+'\n')

# Publish static support/privacy pages beside the game.
for section in ['privacy','support']:
 page=project.parent/'distribution'/section
 if page.exists():shutil.copytree(page,output/section)
archive=output.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as bundle:
 for path in sorted(output.rglob('*')):
  if path.is_file():bundle.write(path,path.relative_to(output))
print(f'Site: {output}\nZIP: {archive} ({archive.stat().st_size/1048576:.1f} MiB)')

# Publish the native demo beside the browser game, outside the browser-only ZIP.
android_source=project.parent/'distribution/android'
if android_source.exists():
 metadata=json.loads((android_source/'build-info.json').read_text())
 apk=android_source/'airlift-demo.apk'
 if apk.stat().st_size!=metadata['bytes'] or hashlib.sha256(apk.read_bytes()).hexdigest()!=metadata['sha256']:
  raise SystemExit('Android APK does not match its recorded size/checksum')
 expected=(android_source/'SHA256SUMS.txt').read_text().split()[0]
 if expected!=metadata['sha256']:raise SystemExit('Android checksum file does not match metadata')
 download=output/'download';download.mkdir()
 for name in ['airlift-demo.apk','SHA256SUMS.txt','INSTALL.md','build-info.json']:
  shutil.copy2(android_source/name,download/name)
 page=(android_source/'index.html').read_text()
 for token,value in {'SIZE':f"{metadata['bytes']/1000000:.1f}",'VERSION':metadata['version'],'SHA':metadata['sha256']}.items():
  page=page.replace('@@'+token+'@@',html.escape(value))
 (download/'index.html').write_text(page)
 shutil.copy2(project/'Assets/Art/app-icon.svg',download/'app-icon.svg')
 print(f"Android download: {download} ({metadata['version']})")

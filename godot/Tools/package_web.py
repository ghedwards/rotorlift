"""Package an existing Godot Web export as a clean Pages site and upload ZIP."""
from pathlib import Path
import argparse, shutil, zipfile, json
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
archive=output.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as bundle:
 for path in sorted(output.rglob('*')):
  if path.is_file():bundle.write(path,path.relative_to(output))
print(f'Site: {output}\nZIP: {archive} ({archive.stat().st_size/1048576:.1f} MiB)')

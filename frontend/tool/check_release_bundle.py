"""Check APK/web archives. Mock assets are allowed only with explicit --demo."""
import argparse, json, sys, zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('bundle');p.add_argument('--demo',action='store_true');a=p.parse_args()
path=Path(a.bundle)
if path.is_dir():names=[str(f.relative_to(path)) for f in path.rglob('*') if f.is_file()]
else:
 with zipfile.ZipFile(path) as z:names=z.namelist()
mocks=[n for n in names if 'assets/mocks/' in n]
private=[n for n in mocks if '/private/' in n or 'PRIVATE_GRADING_KEYS' in n or 'EVALUATION_CONTEXT' in n]
if mocks and not a.demo:sys.exit('FAIL: production bundle contains mock fixtures/private grading data')
if a.demo and not any('/recording/factory_run.json' in n for n in names):sys.exit('FAIL: recording samples missing')
print(json.dumps({'type':'private recording demo' if a.demo else 'production','mock_files':len(mocks),'private_grading_files':len(private),'status':'passed'},indent=2))

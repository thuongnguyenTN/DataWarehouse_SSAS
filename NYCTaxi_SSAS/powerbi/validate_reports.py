"""Validate all PBIR documents against pinned Microsoft JSON schemas."""
from pathlib import Path
import json, urllib.request, urllib.error, hashlib, warnings
from jsonschema import Draft7Validator, RefResolver

ROOT=Path(__file__).parent
CACHE=ROOT/'schemas/cache';CACHE.mkdir(parents=True,exist_ok=True)
def fetch(uri):
    base=uri.split('#')[0]
    assert base.startswith('https://developer.microsoft.com/json-schemas/'),base
    path=CACHE/(hashlib.sha256(base.encode()).hexdigest()+'.json')
    if path.exists():return json.loads(path.read_text())
    url=base.replace('https://developer.microsoft.com/json-schemas/','https://raw.githubusercontent.com/microsoft/json-schemas/main/').replace('schema.embedded.json','schema-embedded.json')
    try:
        data=urllib.request.urlopen(url,timeout=15).read()
    except urllib.error.HTTPError as e:
        if e.code!=404:raise
        data=urllib.request.urlopen(base,timeout=15).read()
    path.write_bytes(data);return json.loads(data)

errors=[];count=0;unavailable=[]
for path in (ROOT/'reports').rglob('*'):
    if not path.is_file() or path.suffix not in ('.json','.pbir','.pbism','.pbip'):continue
    data=json.loads(path.read_text(encoding='utf-8-sig'))
    if path.name=='modelReference.json':
        if data.get('connectionType')!='analysisServicesDatabaseLive':
            errors.append({'file':str(path),'error':'Desktop requires analysisServicesDatabaseLive for this SSAS Live source'})
        if data.get('isMultiDimentional') is not True:
            errors.append({'file':str(path),'error':'Expected a multidimensional live connection'})
    uri=data.get('$schema')
    if not uri:continue
    try:schema=fetch(uri)
    except urllib.error.HTTPError as e:
        if e.code!=404:raise
        unavailable.append({'file':str(path.relative_to(ROOT)),'schema':uri});continue
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        resolver=RefResolver(base_uri=uri,referrer=schema,handlers={'https':fetch})
        found=list(Draft7Validator(schema,resolver=resolver).iter_errors(data))
    count+=1
    for e in found:errors.append({'file':str(path.relative_to(ROOT)),'path':list(e.absolute_path),'error':e.message})
result={'validatedDocuments':count,'errors':errors,'unavailableSchemas':unavailable,'validationComplete':not unavailable,'passed':not errors and not unavailable}
(ROOT/'schema-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
raise SystemExit(bool(errors))

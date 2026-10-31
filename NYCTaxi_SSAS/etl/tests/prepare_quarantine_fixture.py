from pathlib import Path
import sys,json,csv
sys.path.insert(0,str(Path('etl/python').resolve()))
import pyarrow as pa,pyarrow.parquet as pq
import convert_nyc_parquet_to_csv as c
root=Path('etl/tests/quarantine-fixture').resolve()
for dataset in ['yellow','green','fhv','fhvhv']:
 source=root/'raw'/dataset/(dataset+'_tripdata_2025-01.parquet');source.parent.mkdir(parents=True,exist_ok=True)
 pq.write_table(pa.table({name:['1'] for name in c.PROFILES[dataset]}),source)
 target=root/'csv'/dataset/(dataset+'_tripdata_2025-01.csv')
 c.convert_one(source,target,dataset,100,100000,'ssis',False,c.load_arrow())
lookup=root/'raw/lookup/taxi_zone_lookup.csv';lookup.parent.mkdir(parents=True,exist_ok=True)
with lookup.open('w',encoding='utf-8',newline='') as f:
 w=csv.writer(f);w.writerow(c.PROFILES['lookup']);w.writerow(['1','Test','Test Zone','Test'])
c.convert_lookup(root/'raw',root/'csv',False)
meta=root/'csv/yellow/yellow_tripdata_2025-01.csv.meta.json';data=json.loads(meta.read_text());data['contract_version']=999;meta.write_text(json.dumps(data),encoding='utf-8')
print(root)

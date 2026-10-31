"""File-boundary tests against the production converter/inspector."""
from pathlib import Path
import sys,tempfile,unittest,csv
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import pyarrow as pa
import pyarrow.parquet as pq
import convert_nyc_parquet_to_csv as convert
import inspect_extract_file as inspect
from extract_contract import DATASETS,OPTIONAL

class FileBoundaryTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
  self.source=self.root/'yellow_tripdata_2025-01.parquet';self.target=self.root/'yellow_tripdata_2025-01.csv'
 def tearDown(self): self.tmp.cleanup()
 def write(self,extra=False):
  names=[x for x in DATASETS['yellow'][3] if x not in OPTIONAL['yellow']]
  data={x:['1','2','3'] for x in names};data['VendorID']=['a,"b\nc','2','3']
  if extra:data['new_unknown_column']=['x']*3
  pq.write_table(pa.table(data),self.source)
 def run_convert(self,limit=0):
  return convert.convert_one(self.source,self.target,'yellow',2,limit,'ssis',False,convert.load_arrow())
 def test_quoted_csv_and_optional_columns_round_trip(self):
  self.write();self.run_convert()
  info=inspect.inspect_file(self.target,'yellow');self.assertEqual(info['rows'],3)
  with self.target.open(newline='',encoding='utf-8') as f:rows=list(csv.DictReader(f))
  self.assertEqual(rows[0]['VendorID'],'a,"b\nc');self.assertEqual(rows[0]['Airport_fee'],'')
 def test_limit_change_reconverts_and_inspector_rejects_wrong_limit(self):
  self.write();self.run_convert(2)
  self.assertEqual(inspect.inspect_file(self.target,'yellow')['rows'],2)
  with self.assertRaises(ValueError):inspect.ssis_payload(self.target,'yellow','2025-01','2025-01',3)
  self.run_convert(0);self.assertEqual(inspect.inspect_file(self.target,'yellow')['rows'],3)
 def test_hash_corruption_is_detected(self):
  self.write();self.run_convert();data=self.target.read_bytes();self.target.write_bytes(data.replace(b'a,',b'z,',1))
  with self.assertRaises(ValueError):inspect.inspect_file(self.target,'yellow')
 def test_unknown_schema_does_not_publish_output(self):
  self.write(extra=True)
  with self.assertRaises(ValueError):self.run_convert()
  self.assertFalse(self.target.exists())
 def test_out_of_range_file_is_skipped_without_metadata(self):
  value=inspect.ssis_payload(self.root/'yellow_tripdata_2024-01.csv','yellow','2025-01','2025-12',0)
  self.assertTrue(value.startswith('0|0|0|'))
 def test_unchanged_csv_is_reused(self):
  self.write();self.run_convert();before=self.target.stat().st_mtime_ns
  self.assertEqual(self.run_convert()[0],'skipped');self.assertEqual(before,self.target.stat().st_mtime_ns)

if __name__=='__main__':unittest.main()

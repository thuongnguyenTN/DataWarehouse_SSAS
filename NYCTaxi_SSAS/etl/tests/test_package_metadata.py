from pathlib import Path
import sys,subprocess,tempfile,shutil,unittest,importlib.util
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('package_validator',ROOT/'etl/Validate-PackageMetadata.py')
validator=importlib.util.module_from_spec(spec);spec.loader.exec_module(validator)
class PackageMetadataTests(unittest.TestCase):
 def test_regression_detects_old_master_missing_metadata(self):
  backup=sorted((ROOT/'etl/backups').glob('package-load-fix-*'))[0]
  errors=validator.check(backup/'PKG_00_Master.dtsx')
  self.assertEqual(sum('missing CreationName' in e for e in errors),8)
  self.assertIn('OnError missing LoggingOptions',errors)
 def test_regression_detects_untyped_parameter_defaults(self):
  backup=sorted((ROOT/'etl/backups').glob('package-load-fix-*'))[-1]
  errors=validator.check(backup/'PKG_00_Master.dtsx')
  self.assertEqual(sum('ParameterValue DataType missing/mismatch' in e for e in errors),4)
 def test_deployed_packages_have_required_metadata(self):
  for p in Path('E:/NYCTaxi/NYCTaxi_DW/NYCTaxi_ETL').glob('*.dtsx'):
   self.assertEqual(validator.check(p),[],str(p))
 def test_generator_cannot_reintroduce_missing_metadata(self):
  with tempfile.TemporaryDirectory(dir=ROOT/'etl/tests') as folder:
   mirror=Path(folder);seeds=mirror/'etl/original-packages';seeds.mkdir(parents=True)
   for p in (ROOT/'etl/original-packages').iterdir():
    if p.is_file():shutil.copy2(p,seeds/p.name)
   subprocess.run([sys.executable,str(ROOT/'etl/Prepare-Packages.py')],cwd=mirror,check=True,capture_output=True,text=True)
   for p in (mirror/'etl/packages').glob('*.dtsx'):self.assertEqual(validator.check(p),[],str(p))
if __name__=='__main__':unittest.main()

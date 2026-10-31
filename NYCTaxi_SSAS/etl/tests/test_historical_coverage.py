from pathlib import Path
import sys, unittest, tempfile
from types import SimpleNamespace
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from extract_contract import FIRST_MONTH
from convert_nyc_parquet_to_csv import jobs_for

class HistoricalCoverageTests(unittest.TestCase):
    def test_2013_january_requires_yellow_only(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            args = SimpleNamespace(input=root, output=root/'csv', datasets=list(FIRST_MONTH), all=False,
                                   start='2013-01', end='2013-01')
            self.assertEqual(jobs_for(args)[1], [('yellow', '2013-01')])
            (root / 'yellow_tripdata_2013-01.parquet').touch()
            self.assertEqual(jobs_for(args)[1], [])

    def test_first_month_is_required_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as folder:
            for dataset, first in FIRST_MONTH.items():
                args = SimpleNamespace(input=Path(folder), datasets=[dataset], all=False,
                                       start=first, end=first)
                self.assertEqual(jobs_for(args)[1], [(dataset, first)])

if __name__ == '__main__': unittest.main()

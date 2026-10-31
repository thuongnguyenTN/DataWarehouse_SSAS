#!/usr/bin/env python3
"""Validate a prepared CSV and print one exact value for SSIS stdout variables."""
import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path
from extract_contract import CONTRACT_VERSION, DATASETS

ZERO_HASH = "0" * 64


def valid_month(value):
    if not value or not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", value) or int(value[:4]) < 2009:
        raise ValueError("Nhap khoang thang YYYY-MM o Parameters truoc khi chay package.")
    return value


def inspect_file(path, dataset, verify_hash=True):
    info = json.loads(path.with_suffix(path.suffix + ".meta.json").read_text(encoding="utf-8"))
    columns = list(DATASETS[dataset][3])
    if (info.get("contract_version") != CONTRACT_VERSION or info.get("dataset") != dataset
            or info.get("columns") != columns or info.get("line_ending") != "LF"
            or info.get("encoding") != "utf-8" or info.get("csv_size") != path.stat().st_size
            or info.get("schema_mode", "ssis") != "ssis"
            or type(info.get("rows")) is not int or info["rows"] < 0
            or type(info.get("source_rows")) is not int or info["source_rows"] < 0
            or type(info.get("row_limit")) is not int or info["row_limit"] < 0
            or not re.fullmatch(r"[0-9a-f]{64}", str(info.get("sha256", "")))):
        raise ValueError("Invalid CSV metadata")
    expected = min(info["source_rows"], info["row_limit"]) if info["row_limit"] else info["source_rows"]
    if info["rows"] != expected or (dataset == "lookup" and info["row_limit"] != 0):
        raise ValueError("CSV row count / row limit metadata is inconsistent")
    with path.open("rb") as stream:
        first = stream.readline()
        if not first.endswith(b"\n") or first.endswith(b"\r\n"):
            raise ValueError("CSV must use LF row delimiters")
        if next(csv.reader([first.decode("utf-8")])) != columns:
            raise ValueError("CSV header does not match SSIS")
        if verify_hash:
            digest = hashlib.sha256(first)
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
            if digest.hexdigest() != info["sha256"]:
                raise ValueError("CSV content changed after preparation")
    return info


def ssis_payload(path, dataset, start, end, row_limit):
    """Return selected|rows|row_limit|sha256 without a newline for SSIS TOKEN()."""
    start, end = valid_month(start), valid_month(end)
    if start > end or row_limit is None or row_limit < 0:
        raise ValueError("Khoang thang hoac pMaxRows khong hop le.")
    if dataset == "lookup":
        selected = path.name == "taxi_zone_lookup.csv"
        expected_limit = 0
    else:
        prefix = DATASETS[dataset][2]
        match = re.fullmatch(re.escape(prefix) + r"_(\d{4}-(?:0[1-9]|1[0-2]))\.csv", path.name)
        selected = bool(match and start <= match.group(1) <= end)
        expected_limit = row_limit
    # File enumerators can also return *.csv.meta.json / temporary files.
    # Out-of-scope files never require metadata or touch the SQL work buffer.
    if not selected:
        return f"0|0|0|{ZERO_HASH}"
    info = inspect_file(path, dataset)
    if info["row_limit"] != expected_limit:
        raise ValueError("CSV khong khop pMaxRows. Chay lai task convert truoc khi nap Staging.")
    return f"1|{info['rows']}|{info['row_limit']}|{info['sha256']}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, required=True)
    parser.add_argument("--dataset", choices=DATASETS, required=True)
    parser.add_argument("--value", choices=("rows", "sha256", "ssis"), default="rows")
    parser.add_argument("--start", help="Thang bat dau YYYY-MM; bat buoc voi --value ssis")
    parser.add_argument("--end", help="Thang ket thuc YYYY-MM; bat buoc voi --value ssis")
    parser.add_argument("--row-limit", type=int, help="pMaxRows; 0 = toan bo")
    args = parser.parse_args()
    try:
        if args.value == "ssis":
            sys.stdout.write(ssis_payload(args.file, args.dataset, args.start, args.end, args.row_limit))
        else:
            info = inspect_file(args.file, args.dataset, verify_hash=args.value == "rows")
            sys.stdout.write(str(info[args.value]))
        return 0
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Chuyen NYC TLC Parquet sang CSV UTF-8/LF theo batch, khong doc ca file vao RAM.

Chay console de chon khoang thang, hoac dung --start/--end hay --all.
Mac dinh --schema ssis: cot on dinh cho project NYC Taxi hien tai.
--schema source: giu thu tu va tat ca cot goc, phu hop schema cu/khac.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
import uuid
from pathlib import Path

DATASETS = ("yellow", "green", "fhv", "fhvhv")
DEFAULT_INPUT = Path(r"D:\Kho_Du_lieu\NYCTaxi\raw")
DEFAULT_OUTPUT = Path(r"D:\Kho_Du_lieu\NYCTaxi\csv")
from extract_contract import DATASETS as CONTRACT_DATASETS, OPTIONAL
PROFILES = {name: profile[3] for name, profile in CONTRACT_DATASETS.items()}


def valid_month(value):
    value = value.strip()
    if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", value) or int(value[:4]) < 2009:
        raise ValueError("Nhap YYYY-MM, nam tu 2009, thang tu 01 den 12.")
    return value


def month_range(start, end):
    year, month = map(int, start.split("-"))
    while f"{year:04d}-{month:02d}" <= end:
        yield f"{year:04d}-{month:02d}"
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def meta_path(target):
    return target.with_suffix(target.suffix + ".meta.json")


def cleanup_temporary(path):
    """Remove our temporary file without replacing the original conversion error."""
    try:
        path.unlink(missing_ok=True)
    except OSError as exc:
        print(f"[CANH BAO] Khong xoa duoc file tam {path}: {exc}", file=sys.stderr)


def signature(source):
    stat = source.stat()
    return {"source_file": str(source.resolve()), "source_size": stat.st_size,
            "source_mtime_ns": stat.st_mtime_ns}


def write_meta(source, target, dataset, columns, rows, total, row_limit, mode):
    info = {**signature(source), "dataset": dataset, "columns": list(columns),
        "schema_mode": mode, "contract_version": 1 if mode == "ssis" else 0,
        "encoding": "utf-8", "line_ending": "LF", "rows": rows, "source_rows": total,
        "row_limit": row_limit, "csv_size": target.stat().st_size,
        "csv_mtime_ns": target.stat().st_mtime_ns, "sha256": sha256(target)}
    path = meta_path(target)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".part")
    try:
        temporary.write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(path)
    finally:
        cleanup_temporary(temporary)


def reusable(source, target, columns, rows, row_limit, mode):
    try:
        info = json.loads(meta_path(target).read_text(encoding="utf-8"))
        return (all(info.get(k) == v for k, v in signature(source).items())
            and info.get("schema_mode") == mode and info.get("columns") == list(columns)
            and info.get("rows") == rows and info.get("row_limit") == row_limit
            and info.get("csv_size") == target.stat().st_size
            and info.get("sha256") == sha256(target))
    except (OSError, ValueError, TypeError):
        return False


def mapping(dataset, names):
    lookup = {}
    for name in names:
        key = name.casefold()
        if key in lookup:
            raise ValueError("Ten cot trung nhau: " + name)
        lookup[key] = name
    expected = PROFILES[dataset]
    extra = set(lookup) - {name.casefold() for name in expected}
    missing = [name for name in expected if name.casefold() not in lookup and name not in OPTIONAL[dataset]]
    if extra or missing:
        raise ValueError(f"Schema khac SSIS. Cot la={sorted(extra)}, thieu={missing}. "
                         "Dung --schema source de giu nguyen cot goc; sau do doi metadata SSIS.")
    return [lookup.get(name.casefold()) for name in expected]


def load_arrow():
    try:
        import pyarrow as pa
        import pyarrow.compute as pc
        import pyarrow.csv as acsv
        import pyarrow.parquet as pq
        return pa, pc, acsv, pq
    except ImportError as exc:
        raise ValueError(f'Thieu pyarrow. Chay: "{sys.executable}" -m pip install pyarrow') from exc


def convert_one(source, target, dataset, batch_size, row_limit, mode, overwrite, arrow):
    pa, pc, acsv, pq = arrow
    with pq.ParquetFile(source) as parquet:
        total = parquet.metadata.num_rows
        rows = min(total, row_limit) if row_limit else total
        names = PROFILES[dataset] if mode == "ssis" else parquet.schema_arrow.names
        source_names = mapping(dataset, parquet.schema_arrow.names) if mode == "ssis" else None
        schema = pa.schema([(name, pa.string()) for name in names]) if mode == "ssis" else parquet.schema_arrow
        if not overwrite and reusable(source, target, names, rows, row_limit, mode):
            print(f"[BO QUA] CSV hop le: {target} ({rows:,} dong)")
            return "skipped", rows
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + "." + uuid.uuid4().hex + ".part")
        count = 0
        try:
            # CSVWriter.close() does not close a sink it opened from a path.
            # Own the OSFile explicitly so Windows can rename/delete it after writing.
            with pa.OSFile(str(temporary), "wb") as output:
                with acsv.CSVWriter(output, schema, write_options=acsv.WriteOptions(include_header=True)) as writer:
                    for batch in parquet.iter_batches(batch_size=batch_size):
                        if count == rows:
                            break
                        batch = batch.slice(0, min(batch.num_rows, rows - count))
                        if mode == "ssis":
                            arrays = []
                            for name, original in zip(names, source_names):
                                array = (pc.cast(batch.column(batch.schema.get_field_index(original)), pa.string())
                                         if original is not None else pa.nulls(batch.num_rows, pa.string()))
                                maximum = pc.max(pc.binary_length(array)).as_py()
                                if maximum is not None and maximum > 50:
                                    raise ValueError(f"Cot {name} vuot 50 bytes cua Staging; dung --schema source neu can giu gia tri.")
                                arrays.append(array)
                            batch = pa.RecordBatch.from_arrays(arrays, schema=schema)
                        writer.write_batch(batch)
                        count += batch.num_rows
            if count != rows:
                raise ValueError(f"So dong khong khop: {count}/{rows}")
            temporary.replace(target)
            write_meta(source, target, dataset, names, count, total, row_limit, mode)
            print(f"[XONG] {target}: {count:,}/{total:,} dong")
            return "converted", count
        finally:
            cleanup_temporary(temporary)


def convert_lookup(input_root, output_root, overwrite):
    source = input_root / "lookup/taxi_zone_lookup.csv"
    if not source.is_file():
        raise FileNotFoundError("Thieu Taxi Zone Lookup: " + str(source))
    names = PROFILES["lookup"]
    with source.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        source_names = mapping("lookup", reader.fieldnames or [])
        rows = list(reader)
    if not rows:
        raise ValueError("Taxi Zone Lookup rong")
    target = output_root / "lookup/taxi_zone_lookup.csv"
    if not overwrite and reusable(source, target, names, len(rows), 0, "ssis"):
        return "skipped", len(rows)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + "." + uuid.uuid4().hex + ".part")
    try:
        with temporary.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream, lineterminator="\n")
            writer.writerow(names)
            for row in rows:
                if None in row:
                    raise ValueError("Taxi Zone co dong thua cot")
                values = [row.get(name) for name in source_names]
                for name, value in zip(names, values):
                    limit = 50 if name == "LocationID" else 255
                    if value is None or len(value.encode("utf-8")) > limit:
                        raise ValueError("Taxi Zone: gia tri thieu/qua dai o cot " + name)
                writer.writerow(values)
        temporary.replace(target)
        write_meta(source, target, "lookup", names, len(rows), len(rows), 0, "ssis")
        print(f"[XONG] {target}: {len(rows)} dong")
        return "converted", len(rows)
    finally:
        cleanup_temporary(temporary)


def configuration(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Thu muc raw Parquet")
    parser.add_argument("--output", type=Path, help="Thu muc CSV")
    parser.add_argument("--start", help="Thang bat dau YYYY-MM")
    parser.add_argument("--end", help="Thang ket thuc YYYY-MM")
    parser.add_argument("--all", action="store_true", help="Chuyen tat ca cac Parquet da co")
    parser.add_argument("--datasets", nargs="+", type=str.lower, choices=DATASETS)
    parser.add_argument("--batch-size", type=int, default=100000)
    parser.add_argument("--max-rows", type=int, help="0 = toan bo; N > 0 = N dong dau moi file")
    parser.add_argument("--schema", choices=("ssis", "source"), default="ssis")
    parser.add_argument("--lookup", action="store_true", help="Chuan hoa them Taxi Zone CSV neu da tai")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--allow-missing", action="store_true", help="Chap nhan file thang/nguon bi thieu")
    parser.add_argument("--interactive", action="store_true")
    args = parser.parse_args(argv)
    console = args.interactive or bool(not args.all and (args.start is None or args.end is None)
                                        and sys.stdin and sys.stdin.isatty())
    if args.all and (args.start is not None or args.end is not None):
        raise ValueError("Chon --all HOAC --start/--end.")
    if not args.all and (args.start is None or args.end is None):
        if not console:
            raise ValueError("Truyen --start/--end, hoac --all. Console: dung --interactive.")
        if args.start is None:
            args.start = input("Thang bat dau (YYYY-MM, Enter = chuyen tat ca): ").strip()
            if not args.start:
                args.all = True
        if not args.all and args.end is None:
            args.end = input("Thang ket thuc (YYYY-MM): ").strip()
    if not args.all:
        if not args.start or not args.end:
            raise ValueError("Thang bat dau/ket thuc dang trong. Dien Parameters truoc khi chay SSIS.")
        args.start, args.end = valid_month(args.start), valid_month(args.end)
        if args.start > args.end:
            raise ValueError("Thang bat dau lon hon thang ket thuc.")
    for attribute, default, label in [("input", DEFAULT_INPUT, "Thu muc Parquet"),
                                      ("output", DEFAULT_OUTPUT, "Thu muc CSV")]:
        if getattr(args, attribute) is None:
            value = input(f"{label} [{default}]: ").strip() if console else ""
            setattr(args, attribute, Path(value.strip('"')) if value else default)
        setattr(args, attribute, getattr(args, attribute).expanduser().resolve())
    if args.datasets is None:
        value = input("Nguon yellow green fhv fhvhv [Enter = tat ca]: ").strip().lower() if console else ""
        args.datasets = value.replace(",", " ").split() if value else list(DATASETS)
        if any(name not in DATASETS for name in args.datasets):
            raise ValueError("Nguon hop le: yellow, green, fhv, fhvhv.")
    args.datasets = list(dict.fromkeys(args.datasets))
    if args.max_rows is None:
        value = input("Gioi han dong/file [0 = toan bo]: ").strip() if console else ""
        args.max_rows = int(value) if value else 0
    if console and not args.lookup:
        args.lookup = input("Chuan hoa them Taxi Zone da tai? [y/N]: ").strip().lower() in ("y", "yes")
    if args.batch_size < 1 or args.max_rows < 0:
        raise ValueError("--batch-size > 0; --max-rows >= 0.")
    if not args.input.is_dir():
        raise FileNotFoundError("Khong tim thay thu muc Parquet: " + str(args.input))
    if args.input == args.output:
        raise ValueError("Thu muc input va output phai khac nhau de giu nguyen du lieu goc.")
    return args


def jobs_for(args):
    jobs, found = [], set()
    for source in sorted(args.input.rglob("*.parquet")):
        match = re.fullmatch(r"(yellow|green|fhv|fhvhv)_tripdata_(\d{4}-\d{2})\.parquet", source.name)
        if not match or match.group(1) not in args.datasets:
            continue
        dataset, period = match.groups()
        valid_month(period)
        if not args.all and not (args.start <= period <= args.end):
            continue
        relative = source.relative_to(args.input).with_suffix(".csv")
        if relative.parts[0] not in DATASETS:
            relative = Path(dataset) / relative
        jobs.append((source, args.output / relative, dataset))
        found.add((dataset, period))
    missing = []
    if not args.all:
        missing = [(dataset, period) for dataset in args.datasets
                   for period in month_range(args.start, args.end) if (dataset, period) not in found]
    return jobs, missing


def main(argv=None):
    try:
        args = configuration(argv)
        jobs, missing = jobs_for(args)
        for dataset, period in missing:
            print(f"[THIEU FILE] {dataset} {period}; tiep tuc xu ly file da co.", file=sys.stderr)
        if not jobs:
            raise ValueError("Khong co Parquet phu hop nguon va khoang thang da chon.")
        arrow = load_arrow()
        converted = skipped = failed = total_rows = 0
        print(f"Input: {args.input}\nOutput: {args.output}\nSchema: {args.schema}; max-rows: {args.max_rows}")
        for source, target, dataset in jobs:
            try:
                status, count = convert_one(source, target, dataset, args.batch_size,
                                           args.max_rows, args.schema, args.overwrite, arrow)
                converted += status == "converted"
                skipped += status == "skipped"
                total_rows += count
            except Exception as exc:
                failed += 1
                print(f"[LOI] {source}: {exc}", file=sys.stderr)
        if args.lookup:
            try:
                status, count = convert_lookup(args.input, args.output, args.overwrite)
                converted += status == "converted"
                skipped += status == "skipped"
                total_rows += count
            except Exception as exc:
                failed += 1
                print(f"[LOI] Taxi Zone: {exc}", file=sys.stderr)
        print(f"\nTONG KET: converted={converted}, skipped={skipped}, failed={failed}, "
              f"missing={len(missing)}, rows={total_rows:,}")
        return 1 if failed or (missing and not args.allow_missing) else 0
    except (ValueError, OSError, EOFError) as exc:
        print(f"[LOI] {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n[HUY] Nguoi dung dung chuong trinh.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Tai NYC TLC Parquet theo khoang thang tu chon.

Chay truc tiep: nhap thang/nam trong console.
SSIS: truyen --start YYYY-MM --end YYYY-MM --output PATH.
Chi dung thu vien chuan cua Python; khong can pyarrow de tai file.
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import sys
import time
import uuid
from extract_contract import FIRST_MONTH
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
LOOKUP_URL = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
DATASETS = ("yellow", "green", "fhv", "fhvhv")
DEFAULT_OUTPUT = Path(r"D:\Kho_Du_lieu\NYCTaxi\raw")


def valid_month(value):
    value = value.strip()
    if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", value) or int(value[:4]) < 2009:
        raise ValueError("Thang phai co dang YYYY-MM, nam tu 2009, thang tu 01 den 12.")
    return value


def month_range(start, end):
    start, end = valid_month(start), valid_month(end)
    if start > end:
        raise ValueError("Thang bat dau phai nho hon hoac bang thang ket thuc.")
    year, month = map(int, start.split("-"))
    while f"{year:04d}-{month:02d}" <= end:
        yield f"{year:04d}-{month:02d}"
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)


def prompt_month(label):
    while True:
        try:
            return valid_month(input(label).strip())
        except ValueError as exc:
            print(exc)


def parquet_ok(path):
    """Kiem tra signature va vi tri footer; khong thay the giai ma toan bo file."""
    try:
        size = path.stat().st_size
        if size < 12:
            return False
        with path.open("rb") as stream:
            first = stream.read(4)
            stream.seek(-8, os.SEEK_END)
            footer = stream.read(8)
        metadata_size = int.from_bytes(footer[:4], "little")
        return first == b"PAR1" and footer[4:] == b"PAR1" and 0 < metadata_size <= size - 12
    except OSError:
        return False


def lookup_ok(path):
    try:
        with path.open(encoding="utf-8-sig", newline="") as stream:
            rows = csv.reader(stream)
            return next(rows) == ["LocationID", "Borough", "Zone", "service_zone"] and next(rows, None) is not None
    except (OSError, UnicodeError, StopIteration, csv.Error):
        return False


def download_one(url, destination, retries=3, timeout=60, overwrite=False, lookup=False):
    check = lookup_ok if lookup else parquet_ok
    if not overwrite and check(destination):
        print(f"[BO QUA] Da co file hop le: {destination}")
        return "skipped"
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + "." + uuid.uuid4().hex + ".part")
    for attempt in range(1, retries + 1):
        try:
            print(f"[TAI {attempt}/{retries}] {url}")
            request = Request(url, headers={"User-Agent": "NYC-Taxi-DWH-Python/1.0"})
            with urlopen(request, timeout=timeout) as response, temporary.open("wb") as stream:
                expected = int(response.headers.get("Content-Length", 0))
                received = 0
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    stream.write(block)
                    received += len(block)
            if expected and received != expected:
                raise ValueError(f"File tai chua du: {received}/{expected} bytes")
            if not check(temporary):
                raise ValueError("File tai ve khong dung dinh dang hoac footer khong hop le.")
            temporary.replace(destination)
            print(f"[XONG] {destination} ({received:,} bytes)")
            return "downloaded"
        except HTTPError as exc:
            if exc.code == 404:
                print(f"[KHONG CO] HTTP 404: {url}")
                temporary.unlink(missing_ok=True)
                return "missing"
            message = f"HTTP {exc.code}: {exc.reason}"
        except (URLError, OSError, TimeoutError, ValueError) as exc:
            message = str(exc)
        except KeyboardInterrupt:
            temporary.unlink(missing_ok=True)
            raise
        temporary.unlink(missing_ok=True)
        print(f"[LOI] {message}", file=sys.stderr)
        if attempt < retries:
            time.sleep(min(attempt * 2, 6))
    return "failed"


def configuration(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", help="Thang bat dau YYYY-MM")
    parser.add_argument("--end", help="Thang ket thuc YYYY-MM")
    parser.add_argument("--output", type=Path, help="Thu muc Parquet goc")
    parser.add_argument("--datasets", nargs="+", type=str.lower, choices=DATASETS)
    parser.add_argument("--lookup", action="store_true", help="Tai them Taxi Zone Lookup CSV")
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--overwrite", action="store_true", help="Tai lai file da ton tai")
    parser.add_argument("--allow-missing", action="store_true", help="Chap nhan file HTTP 404; van can co it nhat mot Parquet")
    parser.add_argument("--interactive", action="store_true", help="Bat buoc hoi trong console; khong dung voi SSIS")
    args = parser.parse_args(argv)
    console = args.interactive or bool((args.start is None or args.end is None)
                                        and sys.stdin and sys.stdin.isatty())
    if args.start is None or args.end is None:
        if not console:
            raise ValueError("Thieu --start/--end. SSIS: dien pStartMonth, pEndMonth. Console: dung --interactive.")
        args.start = args.start if args.start is not None else prompt_month("Thang bat dau (YYYY-MM): ")
        args.end = args.end if args.end is not None else prompt_month("Thang ket thuc (YYYY-MM): ")
    if not args.start.strip() or not args.end.strip():
        raise ValueError("--start/--end dang trong. Nhap khoang thang o Parameters truoc khi chay SSIS.")
    args.start, args.end = valid_month(args.start), valid_month(args.end)
    if args.start > args.end:
        raise ValueError("Thang bat dau lon hon thang ket thuc.")
    if args.output is None:
        value = input(f"Thu muc luu Parquet [{DEFAULT_OUTPUT}]: ").strip() if console else ""
        args.output = Path(value.strip('"')) if value else DEFAULT_OUTPUT
    if args.datasets is None:
        value = input("Nguon yellow green fhv fhvhv [Enter = tat ca]: ").strip().lower() if console else ""
        args.datasets = value.replace(",", " ").split() if value else list(DATASETS)
        if any(name not in DATASETS for name in args.datasets):
            raise ValueError("Nguon hop le: yellow, green, fhv, fhvhv.")
    args.datasets = list(dict.fromkeys(args.datasets))
    if console and not args.lookup:
        args.lookup = input("Tai them Taxi Zone Lookup? [y/N]: ").strip().lower() in ("y", "yes")
    if args.retries < 1 or args.timeout <= 0:
        raise ValueError("--retries >= 1 va --timeout > 0.")
    args.output = args.output.expanduser().resolve()
    return args


def main(argv=None):
    try:
        args = configuration(argv)
        periods = list(month_range(args.start, args.end))
        print(f"Khoang thang: {args.start} -> {args.end}")
        print(f"Thu muc raw : {args.output}")
        stats = {name: 0 for name in ("downloaded", "skipped", "missing", "failed")}
        for dataset in args.datasets:
            for period in periods:
                if period < FIRST_MONTH[dataset]:
                    print(f"[NOT_APPLICABLE] {dataset} {period}; first month {FIRST_MONTH[dataset]}")
                    continue
                year, month = period.split("-")
                filename = f"{dataset}_tripdata_{period}.parquet"
                target = args.output / dataset / f"year={year}" / f"month={month}" / filename
                status = download_one(f"{BASE_URL}/{filename}", target, args.retries, args.timeout, args.overwrite)
                stats[status] += 1
        valid_trips = stats["downloaded"] + stats["skipped"]
        if args.lookup:
            status = download_one(LOOKUP_URL, args.output / "lookup/taxi_zone_lookup.csv",
                                  args.retries, args.timeout, args.overwrite, lookup=True)
            stats[status] += 1
        print("\nTONG KET: " + ", ".join(f"{name}={count}" for name, count in stats.items()))
        if stats["failed"] or (stats["missing"] and not args.allow_missing) or not valid_trips:
            print("[CHUA DU] Da xu ly cac file con lai. Xem dong LOI/KHONG CO ben tren.", file=sys.stderr)
            return 1
        return 0
    except (ValueError, OSError, EOFError) as exc:
        print(f"[LOI] {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n[HUY] Nguoi dung dung chuong trinh.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())

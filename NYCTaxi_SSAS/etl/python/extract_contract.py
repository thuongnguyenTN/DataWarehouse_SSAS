"""CSV column order used by both Python and SSIS; business cleaning is separate."""

CONTRACT_VERSION = 1
FIRST_MONTH = {"yellow": "2009-01", "green": "2013-08", "fhv": "2015-01", "fhvhv": "2019-02"}
DATASETS = {
    "yellow": ("Yellow", "YellowTrip", "yellow_tripdata", (
        "VendorID", "tpep_pickup_datetime", "tpep_dropoff_datetime",
        "passenger_count", "trip_distance", "RatecodeID", "store_and_fwd_flag",
        "PULocationID", "DOLocationID", "payment_type", "fare_amount", "extra",
        "mta_tax", "tip_amount", "tolls_amount", "improvement_surcharge",
        "total_amount", "congestion_surcharge", "Airport_fee", "cbd_congestion_fee",
    )),
    "green": ("Green", "GreenTrip", "green_tripdata", (
        "VendorID", "lpep_pickup_datetime", "lpep_dropoff_datetime",
        "store_and_fwd_flag", "RatecodeID", "PULocationID", "DOLocationID",
        "passenger_count", "trip_distance", "fare_amount", "extra", "mta_tax",
        "tip_amount", "tolls_amount", "ehail_fee", "improvement_surcharge",
        "total_amount", "payment_type", "trip_type", "congestion_surcharge",
        "cbd_congestion_fee",
    )),
    "fhv": ("FHV", "FHVTrip", "fhv_tripdata", (
        "dispatching_base_num", "pickup_datetime", "dropOff_datetime",
        "PULocationID", "DOLocationID", "SR_Flag", "Affiliated_base_number",
    )),
    "fhvhv": ("FHVHV", "FHVHVTrip", "fhvhv_tripdata", (
        "hvfhs_license_num", "dispatching_base_num", "originating_base_num",
        "request_datetime", "on_scene_datetime", "pickup_datetime",
        "dropoff_datetime", "PULocationID", "DOLocationID", "trip_miles",
        "trip_time", "base_passenger_fare", "tolls", "bcf", "sales_tax",
        "congestion_surcharge", "airport_fee", "tips", "driver_pay",
        "shared_request_flag", "shared_match_flag", "access_a_ride_flag",
        "wav_request_flag", "wav_match_flag", "cbd_congestion_fee",
    )),
    "lookup": ("TaxiZone", "TaxiZone", "taxi_zone_lookup", (
        "LocationID", "Borough", "Zone", "service_zone",
    )),
}
OPTIONAL = {
    "yellow": {"congestion_surcharge", "Airport_fee", "cbd_congestion_fee"},
    "green": {"ehail_fee", "congestion_surcharge", "cbd_congestion_fee"},
    "fhv": {"SR_Flag", "Affiliated_base_number"},
    "fhvhv": {"cbd_congestion_fee"},
    "lookup": set(),
}


def width(dataset, column):
    return 255 if dataset == "lookup" and column != "LocationID" else 50


def column_mapping(dataset, source_names):
    """Accept case variants; reject ambiguous, missing essential, or new columns."""
    mapped = {}
    for name in source_names:
        key = name.casefold()
        if key in mapped:
            raise ValueError("Duplicate column, ignoring case: " + name)
        mapped[key] = name
    expected = DATASETS[dataset][3]
    unknown = set(mapped) - {name.casefold() for name in expected}
    if unknown:
        raise ValueError("Unsupported source columns: " + ", ".join(sorted(unknown)))
    missing = [name for name in expected
               if name.casefold() not in mapped and name not in OPTIONAL[dataset]]
    if missing:
        raise ValueError("Missing essential columns: " + ", ".join(missing))
    return [mapped.get(name.casefold()) for name in expected]

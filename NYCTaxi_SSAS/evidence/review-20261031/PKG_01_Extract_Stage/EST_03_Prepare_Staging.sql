SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_NAME() <> N'NYCTaxi_Staging' THROW 51000, 'Use NYCTaxi_Staging connection.', 1;
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl');
IF SCHEMA_ID(N'wrk') IS NULL EXEC(N'CREATE SCHEMA wrk');
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');

IF OBJECT_ID(N'stg.YellowTrip', N'U') IS NULL
    CREATE TABLE stg.[YellowTrip] (
    [VendorID] VARCHAR(50) NULL,
    [tpep_pickup_datetime] VARCHAR(50) NULL,
    [tpep_dropoff_datetime] VARCHAR(50) NULL,
    [passenger_count] VARCHAR(50) NULL,
    [trip_distance] VARCHAR(50) NULL,
    [RatecodeID] VARCHAR(50) NULL,
    [store_and_fwd_flag] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [payment_type] VARCHAR(50) NULL,
    [fare_amount] VARCHAR(50) NULL,
    [extra] VARCHAR(50) NULL,
    [mta_tax] VARCHAR(50) NULL,
    [tip_amount] VARCHAR(50) NULL,
    [tolls_amount] VARCHAR(50) NULL,
    [improvement_surcharge] VARCHAR(50) NULL,
    [total_amount] VARCHAR(50) NULL,
    [congestion_surcharge] VARCHAR(50) NULL,
    [Airport_fee] VARCHAR(50) NULL,
    [cbd_congestion_fee] VARCHAR(50) NULL
    );
IF COL_LENGTH(N'stg.YellowTrip', N'ETLSourceKey') IS NULL
    ALTER TABLE stg.[YellowTrip] ADD ETLSourceKey NVARCHAR(260) NULL;
IF COL_LENGTH(N'stg.YellowTrip', N'ETLFileHash') IS NULL
    ALTER TABLE stg.[YellowTrip] ADD ETLFileHash CHAR(64) NULL;
IF COL_LENGTH(N'stg.YellowTrip', N'ETLLoadedAt') IS NULL
    ALTER TABLE stg.[YellowTrip] ADD ETLLoadedAt DATETIME2(0) NULL;
IF OBJECT_ID(N'wrk.YellowTrip', N'U') IS NULL
    CREATE TABLE wrk.[YellowTrip] (
    [VendorID] VARCHAR(50) NULL,
    [tpep_pickup_datetime] VARCHAR(50) NULL,
    [tpep_dropoff_datetime] VARCHAR(50) NULL,
    [passenger_count] VARCHAR(50) NULL,
    [trip_distance] VARCHAR(50) NULL,
    [RatecodeID] VARCHAR(50) NULL,
    [store_and_fwd_flag] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [payment_type] VARCHAR(50) NULL,
    [fare_amount] VARCHAR(50) NULL,
    [extra] VARCHAR(50) NULL,
    [mta_tax] VARCHAR(50) NULL,
    [tip_amount] VARCHAR(50) NULL,
    [tolls_amount] VARCHAR(50) NULL,
    [improvement_surcharge] VARCHAR(50) NULL,
    [total_amount] VARCHAR(50) NULL,
    [congestion_surcharge] VARCHAR(50) NULL,
    [Airport_fee] VARCHAR(50) NULL,
    [cbd_congestion_fee] VARCHAR(50) NULL
    );

IF COL_LENGTH(N'stg.YellowTrip', N'VendorID') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.VendorID', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'tpep_pickup_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.tpep_pickup_datetime', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'tpep_dropoff_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.tpep_dropoff_datetime', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'passenger_count') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.passenger_count', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'trip_distance') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.trip_distance', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'RatecodeID') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.RatecodeID', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'store_and_fwd_flag') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.store_and_fwd_flag', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'PULocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.PULocationID', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'DOLocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.DOLocationID', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'payment_type') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.payment_type', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'fare_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.fare_amount', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'extra') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.extra', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'mta_tax') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.mta_tax', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'tip_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.tip_amount', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'tolls_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.tolls_amount', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'improvement_surcharge') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.improvement_surcharge', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'total_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.total_amount', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'congestion_surcharge') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.congestion_surcharge', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'Airport_fee') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.Airport_fee', 1;

IF COL_LENGTH(N'stg.YellowTrip', N'cbd_congestion_fee') IS NULL
    THROW 51001, 'Missing staging column: stg.YellowTrip.cbd_congestion_fee', 1;

IF OBJECT_ID(N'stg.GreenTrip', N'U') IS NULL
    CREATE TABLE stg.[GreenTrip] (
    [VendorID] VARCHAR(50) NULL,
    [lpep_pickup_datetime] VARCHAR(50) NULL,
    [lpep_dropoff_datetime] VARCHAR(50) NULL,
    [store_and_fwd_flag] VARCHAR(50) NULL,
    [RatecodeID] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [passenger_count] VARCHAR(50) NULL,
    [trip_distance] VARCHAR(50) NULL,
    [fare_amount] VARCHAR(50) NULL,
    [extra] VARCHAR(50) NULL,
    [mta_tax] VARCHAR(50) NULL,
    [tip_amount] VARCHAR(50) NULL,
    [tolls_amount] VARCHAR(50) NULL,
    [ehail_fee] VARCHAR(50) NULL,
    [improvement_surcharge] VARCHAR(50) NULL,
    [total_amount] VARCHAR(50) NULL,
    [payment_type] VARCHAR(50) NULL,
    [trip_type] VARCHAR(50) NULL,
    [congestion_surcharge] VARCHAR(50) NULL,
    [cbd_congestion_fee] VARCHAR(50) NULL
    );
IF COL_LENGTH(N'stg.GreenTrip', N'ETLSourceKey') IS NULL
    ALTER TABLE stg.[GreenTrip] ADD ETLSourceKey NVARCHAR(260) NULL;
IF COL_LENGTH(N'stg.GreenTrip', N'ETLFileHash') IS NULL
    ALTER TABLE stg.[GreenTrip] ADD ETLFileHash CHAR(64) NULL;
IF COL_LENGTH(N'stg.GreenTrip', N'ETLLoadedAt') IS NULL
    ALTER TABLE stg.[GreenTrip] ADD ETLLoadedAt DATETIME2(0) NULL;
IF OBJECT_ID(N'wrk.GreenTrip', N'U') IS NULL
    CREATE TABLE wrk.[GreenTrip] (
    [VendorID] VARCHAR(50) NULL,
    [lpep_pickup_datetime] VARCHAR(50) NULL,
    [lpep_dropoff_datetime] VARCHAR(50) NULL,
    [store_and_fwd_flag] VARCHAR(50) NULL,
    [RatecodeID] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [passenger_count] VARCHAR(50) NULL,
    [trip_distance] VARCHAR(50) NULL,
    [fare_amount] VARCHAR(50) NULL,
    [extra] VARCHAR(50) NULL,
    [mta_tax] VARCHAR(50) NULL,
    [tip_amount] VARCHAR(50) NULL,
    [tolls_amount] VARCHAR(50) NULL,
    [ehail_fee] VARCHAR(50) NULL,
    [improvement_surcharge] VARCHAR(50) NULL,
    [total_amount] VARCHAR(50) NULL,
    [payment_type] VARCHAR(50) NULL,
    [trip_type] VARCHAR(50) NULL,
    [congestion_surcharge] VARCHAR(50) NULL,
    [cbd_congestion_fee] VARCHAR(50) NULL
    );

IF COL_LENGTH(N'stg.GreenTrip', N'VendorID') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.VendorID', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'lpep_pickup_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.lpep_pickup_datetime', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'lpep_dropoff_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.lpep_dropoff_datetime', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'store_and_fwd_flag') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.store_and_fwd_flag', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'RatecodeID') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.RatecodeID', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'PULocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.PULocationID', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'DOLocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.DOLocationID', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'passenger_count') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.passenger_count', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'trip_distance') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.trip_distance', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'fare_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.fare_amount', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'extra') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.extra', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'mta_tax') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.mta_tax', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'tip_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.tip_amount', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'tolls_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.tolls_amount', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'ehail_fee') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.ehail_fee', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'improvement_surcharge') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.improvement_surcharge', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'total_amount') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.total_amount', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'payment_type') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.payment_type', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'trip_type') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.trip_type', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'congestion_surcharge') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.congestion_surcharge', 1;

IF COL_LENGTH(N'stg.GreenTrip', N'cbd_congestion_fee') IS NULL
    THROW 51001, 'Missing staging column: stg.GreenTrip.cbd_congestion_fee', 1;

IF OBJECT_ID(N'stg.FHVTrip', N'U') IS NULL
    CREATE TABLE stg.[FHVTrip] (
    [dispatching_base_num] VARCHAR(50) NULL,
    [pickup_datetime] VARCHAR(50) NULL,
    [dropOff_datetime] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [SR_Flag] VARCHAR(50) NULL,
    [Affiliated_base_number] VARCHAR(50) NULL
    );
IF COL_LENGTH(N'stg.FHVTrip', N'ETLSourceKey') IS NULL
    ALTER TABLE stg.[FHVTrip] ADD ETLSourceKey NVARCHAR(260) NULL;
IF COL_LENGTH(N'stg.FHVTrip', N'ETLFileHash') IS NULL
    ALTER TABLE stg.[FHVTrip] ADD ETLFileHash CHAR(64) NULL;
IF COL_LENGTH(N'stg.FHVTrip', N'ETLLoadedAt') IS NULL
    ALTER TABLE stg.[FHVTrip] ADD ETLLoadedAt DATETIME2(0) NULL;
IF OBJECT_ID(N'wrk.FHVTrip', N'U') IS NULL
    CREATE TABLE wrk.[FHVTrip] (
    [dispatching_base_num] VARCHAR(50) NULL,
    [pickup_datetime] VARCHAR(50) NULL,
    [dropOff_datetime] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [SR_Flag] VARCHAR(50) NULL,
    [Affiliated_base_number] VARCHAR(50) NULL
    );

IF COL_LENGTH(N'stg.FHVTrip', N'dispatching_base_num') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVTrip.dispatching_base_num', 1;

IF COL_LENGTH(N'stg.FHVTrip', N'pickup_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVTrip.pickup_datetime', 1;

IF COL_LENGTH(N'stg.FHVTrip', N'dropOff_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVTrip.dropOff_datetime', 1;

IF COL_LENGTH(N'stg.FHVTrip', N'PULocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVTrip.PULocationID', 1;

IF COL_LENGTH(N'stg.FHVTrip', N'DOLocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVTrip.DOLocationID', 1;

IF COL_LENGTH(N'stg.FHVTrip', N'SR_Flag') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVTrip.SR_Flag', 1;

IF COL_LENGTH(N'stg.FHVTrip', N'Affiliated_base_number') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVTrip.Affiliated_base_number', 1;

IF OBJECT_ID(N'stg.FHVHVTrip', N'U') IS NULL
    CREATE TABLE stg.[FHVHVTrip] (
    [hvfhs_license_num] VARCHAR(50) NULL,
    [dispatching_base_num] VARCHAR(50) NULL,
    [originating_base_num] VARCHAR(50) NULL,
    [request_datetime] VARCHAR(50) NULL,
    [on_scene_datetime] VARCHAR(50) NULL,
    [pickup_datetime] VARCHAR(50) NULL,
    [dropoff_datetime] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [trip_miles] VARCHAR(50) NULL,
    [trip_time] VARCHAR(50) NULL,
    [base_passenger_fare] VARCHAR(50) NULL,
    [tolls] VARCHAR(50) NULL,
    [bcf] VARCHAR(50) NULL,
    [sales_tax] VARCHAR(50) NULL,
    [congestion_surcharge] VARCHAR(50) NULL,
    [airport_fee] VARCHAR(50) NULL,
    [tips] VARCHAR(50) NULL,
    [driver_pay] VARCHAR(50) NULL,
    [shared_request_flag] VARCHAR(50) NULL,
    [shared_match_flag] VARCHAR(50) NULL,
    [access_a_ride_flag] VARCHAR(50) NULL,
    [wav_request_flag] VARCHAR(50) NULL,
    [wav_match_flag] VARCHAR(50) NULL,
    [cbd_congestion_fee] VARCHAR(50) NULL
    );
IF COL_LENGTH(N'stg.FHVHVTrip', N'ETLSourceKey') IS NULL
    ALTER TABLE stg.[FHVHVTrip] ADD ETLSourceKey NVARCHAR(260) NULL;
IF COL_LENGTH(N'stg.FHVHVTrip', N'ETLFileHash') IS NULL
    ALTER TABLE stg.[FHVHVTrip] ADD ETLFileHash CHAR(64) NULL;
IF COL_LENGTH(N'stg.FHVHVTrip', N'ETLLoadedAt') IS NULL
    ALTER TABLE stg.[FHVHVTrip] ADD ETLLoadedAt DATETIME2(0) NULL;
IF OBJECT_ID(N'wrk.FHVHVTrip', N'U') IS NULL
    CREATE TABLE wrk.[FHVHVTrip] (
    [hvfhs_license_num] VARCHAR(50) NULL,
    [dispatching_base_num] VARCHAR(50) NULL,
    [originating_base_num] VARCHAR(50) NULL,
    [request_datetime] VARCHAR(50) NULL,
    [on_scene_datetime] VARCHAR(50) NULL,
    [pickup_datetime] VARCHAR(50) NULL,
    [dropoff_datetime] VARCHAR(50) NULL,
    [PULocationID] VARCHAR(50) NULL,
    [DOLocationID] VARCHAR(50) NULL,
    [trip_miles] VARCHAR(50) NULL,
    [trip_time] VARCHAR(50) NULL,
    [base_passenger_fare] VARCHAR(50) NULL,
    [tolls] VARCHAR(50) NULL,
    [bcf] VARCHAR(50) NULL,
    [sales_tax] VARCHAR(50) NULL,
    [congestion_surcharge] VARCHAR(50) NULL,
    [airport_fee] VARCHAR(50) NULL,
    [tips] VARCHAR(50) NULL,
    [driver_pay] VARCHAR(50) NULL,
    [shared_request_flag] VARCHAR(50) NULL,
    [shared_match_flag] VARCHAR(50) NULL,
    [access_a_ride_flag] VARCHAR(50) NULL,
    [wav_request_flag] VARCHAR(50) NULL,
    [wav_match_flag] VARCHAR(50) NULL,
    [cbd_congestion_fee] VARCHAR(50) NULL
    );

IF COL_LENGTH(N'stg.FHVHVTrip', N'hvfhs_license_num') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.hvfhs_license_num', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'dispatching_base_num') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.dispatching_base_num', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'originating_base_num') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.originating_base_num', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'request_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.request_datetime', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'on_scene_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.on_scene_datetime', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'pickup_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.pickup_datetime', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'dropoff_datetime') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.dropoff_datetime', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'PULocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.PULocationID', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'DOLocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.DOLocationID', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'trip_miles') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.trip_miles', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'trip_time') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.trip_time', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'base_passenger_fare') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.base_passenger_fare', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'tolls') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.tolls', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'bcf') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.bcf', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'sales_tax') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.sales_tax', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'congestion_surcharge') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.congestion_surcharge', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'airport_fee') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.airport_fee', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'tips') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.tips', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'driver_pay') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.driver_pay', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'shared_request_flag') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.shared_request_flag', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'shared_match_flag') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.shared_match_flag', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'access_a_ride_flag') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.access_a_ride_flag', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'wav_request_flag') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.wav_request_flag', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'wav_match_flag') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.wav_match_flag', 1;

IF COL_LENGTH(N'stg.FHVHVTrip', N'cbd_congestion_fee') IS NULL
    THROW 51001, 'Missing staging column: stg.FHVHVTrip.cbd_congestion_fee', 1;

IF OBJECT_ID(N'stg.TaxiZone', N'U') IS NULL
    CREATE TABLE stg.[TaxiZone] (
    [LocationID] VARCHAR(50) NULL,
    [Borough] VARCHAR(255) NULL,
    [Zone] VARCHAR(255) NULL,
    [service_zone] VARCHAR(255) NULL
    );
IF COL_LENGTH(N'stg.TaxiZone', N'ETLSourceKey') IS NULL
    ALTER TABLE stg.[TaxiZone] ADD ETLSourceKey NVARCHAR(260) NULL;
IF COL_LENGTH(N'stg.TaxiZone', N'ETLFileHash') IS NULL
    ALTER TABLE stg.[TaxiZone] ADD ETLFileHash CHAR(64) NULL;
IF COL_LENGTH(N'stg.TaxiZone', N'ETLLoadedAt') IS NULL
    ALTER TABLE stg.[TaxiZone] ADD ETLLoadedAt DATETIME2(0) NULL;
IF OBJECT_ID(N'wrk.TaxiZone', N'U') IS NULL
    CREATE TABLE wrk.[TaxiZone] (
    [LocationID] VARCHAR(50) NULL,
    [Borough] VARCHAR(255) NULL,
    [Zone] VARCHAR(255) NULL,
    [service_zone] VARCHAR(255) NULL
    );

IF COL_LENGTH(N'stg.TaxiZone', N'LocationID') IS NULL
    THROW 51001, 'Missing staging column: stg.TaxiZone.LocationID', 1;

IF COL_LENGTH(N'stg.TaxiZone', N'Borough') IS NULL
    THROW 51001, 'Missing staging column: stg.TaxiZone.Borough', 1;

IF COL_LENGTH(N'stg.TaxiZone', N'Zone') IS NULL
    THROW 51001, 'Missing staging column: stg.TaxiZone.Zone', 1;

IF COL_LENGTH(N'stg.TaxiZone', N'service_zone') IS NULL
    THROW 51001, 'Missing staging column: stg.TaxiZone.service_zone', 1;

IF OBJECT_ID(N'etl.ExtractFileLog', N'U') IS NULL
CREATE TABLE etl.ExtractFileLog (
    DatasetCode VARCHAR(20) NOT NULL,
    SourceKey NVARCHAR(260) NOT NULL,
    FilePath NVARCHAR(500) NOT NULL,
    FileHash CHAR(64) NOT NULL,
    RowLimit INT NOT NULL,
    ExpectedRows BIGINT NOT NULL,
    RowsLoaded BIGINT NULL,
    LoadStatus VARCHAR(20) NOT NULL,
    StartedAt DATETIME2(0) NOT NULL,
    CompletedAt DATETIME2(0) NULL,
    ErrorMessage NVARCHAR(2000) NULL,
    CONSTRAINT PK_ExtractFileLog PRIMARY KEY (DatasetCode, SourceKey),
    CONSTRAINT CK_ExtractFileLog_Status CHECK (LoadStatus IN ('LOADING','SUCCEEDED','FAILED'))
);

EXEC(N'CREATE OR ALTER PROCEDURE etl.usp_BeginExtractFile
    @DatasetCode VARCHAR(20), @FilePath NVARCHAR(500), @FileHash CHAR(64),
    @ExpectedRows BIGINT, @RowLimit INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Table SYSNAME = CASE @DatasetCode WHEN ''yellow'' THEN ''YellowTrip'' WHEN ''green'' THEN ''GreenTrip'' WHEN ''fhv'' THEN ''FHVTrip'' WHEN ''fhvhv'' THEN ''FHVHVTrip'' WHEN ''lookup'' THEN ''TaxiZone'' END;
    IF @Table IS NULL OR @ExpectedRows IS NULL OR @ExpectedRows < 0 OR @RowLimit IS NULL OR @RowLimit < 0
        OR @FileHash IS NULL OR LEN(@FileHash) <> 64
        OR @FileHash COLLATE Latin1_General_BIN2 LIKE ''%[^0-9a-f]%''
        THROW 51002, ''Invalid extraction metadata.'', 1;
    DECLARE @SourceKey NVARCHAR(260) = RIGHT(REPLACE(@FilePath, ''/'', ''\''),
        CHARINDEX(''\'', REVERSE(REPLACE(@FilePath, ''/'', ''\'')) + ''\'') - 1);
    DECLARE @Count BIGINT = 0, @WrongHash BIGINT = 0, @AlreadyLoaded INT = 0, @Sql NVARCHAR(MAX);
    IF EXISTS (SELECT 1 FROM etl.ExtractFileLog WHERE DatasetCode = @DatasetCode
        AND SourceKey = @SourceKey AND FileHash = @FileHash AND RowLimit = @RowLimit
        AND ExpectedRows = @ExpectedRows AND RowsLoaded = @ExpectedRows AND LoadStatus = ''SUCCEEDED'')
    BEGIN
        SET @Sql = N''SELECT @n = COUNT_BIG(*),
                          @bad = COUNT_BIG(CASE WHEN ETLFileHash = @h THEN NULL ELSE 1 END)
                    FROM stg.'' + QUOTENAME(@Table) + N'' WHERE ETLSourceKey = @k;'';
        EXEC sys.sp_executesql @Sql,
            N''@k NVARCHAR(260), @h CHAR(64), @n BIGINT OUTPUT, @bad BIGINT OUTPUT'',
            @SourceKey, @FileHash, @Count OUTPUT, @WrongHash OUTPUT;
        IF @Count = @ExpectedRows AND @WrongHash = 0 SET @AlreadyLoaded = 1;
    END;
    IF @AlreadyLoaded = 0
    BEGIN
        SET @Sql = N''TRUNCATE TABLE wrk.'' + QUOTENAME(@Table) + N'';'';
        EXEC sys.sp_executesql @Sql;
        IF EXISTS (SELECT 1 FROM etl.ExtractFileLog WHERE DatasetCode = @DatasetCode AND SourceKey = @SourceKey)
            UPDATE etl.ExtractFileLog SET FilePath = @FilePath, FileHash = @FileHash,
                RowLimit = @RowLimit, ExpectedRows = @ExpectedRows, RowsLoaded = NULL,
                LoadStatus = ''LOADING'', StartedAt = SYSDATETIME(), CompletedAt = NULL, ErrorMessage = NULL
            WHERE DatasetCode = @DatasetCode AND SourceKey = @SourceKey;
        ELSE
            INSERT etl.ExtractFileLog (DatasetCode, SourceKey, FilePath, FileHash, RowLimit,
                ExpectedRows, LoadStatus, StartedAt)
            VALUES (@DatasetCode, @SourceKey, @FilePath, @FileHash, @RowLimit,
                @ExpectedRows, ''LOADING'', SYSDATETIME());
    END
    ELSE
        UPDATE etl.ExtractFileLog SET FilePath = @FilePath
        WHERE DatasetCode = @DatasetCode AND SourceKey = @SourceKey;
    SELECT @AlreadyLoaded AS AlreadyLoaded, CAST(0 AS BIGINT) AS RowsLoaded;
END;');

EXEC(N'CREATE OR ALTER PROCEDURE etl.usp_CommitExtractFile
    @DatasetCode VARCHAR(20), @FilePath NVARCHAR(500), @FileHash CHAR(64),
    @ExpectedRows BIGINT, @RowLimit INT, @RowsLoaded BIGINT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @SourceKey NVARCHAR(260) = RIGHT(REPLACE(@FilePath, ''/'', ''\''),
        CHARINDEX(''\'', REVERSE(REPLACE(@FilePath, ''/'', ''\'')) + ''\'') - 1);
    DECLARE @Count BIGINT;
    IF @ExpectedRows IS NULL OR @ExpectedRows < 0 OR @RowsLoaded IS NULL
        THROW 51004, ''Invalid row count.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM etl.ExtractFileLog WITH (UPDLOCK, HOLDLOCK)
            WHERE DatasetCode = @DatasetCode AND SourceKey = @SourceKey
                AND FileHash = @FileHash AND ExpectedRows = @ExpectedRows
                AND RowLimit = @RowLimit AND LoadStatus = ''LOADING'')
            THROW 51009, ''The prepared file load record changed before commit.'', 1;
    IF @DatasetCode = ''yellow''
    BEGIN
        SELECT @Count = COUNT_BIG(*) FROM wrk.[YellowTrip];
        IF @Count <> @ExpectedRows OR @RowsLoaded <> @ExpectedRows
            THROW 51003, ''Loaded row count does not match CSV metadata.'', 1;
        DELETE FROM stg.[YellowTrip] WHERE ETLSourceKey = @SourceKey;
        INSERT stg.[YellowTrip] ([VendorID], [tpep_pickup_datetime], [tpep_dropoff_datetime], [passenger_count], [trip_distance], [RatecodeID], [store_and_fwd_flag], [PULocationID], [DOLocationID], [payment_type], [fare_amount], [extra], [mta_tax], [tip_amount], [tolls_amount], [improvement_surcharge], [total_amount], [congestion_surcharge], [Airport_fee], [cbd_congestion_fee], ETLSourceKey, ETLFileHash, ETLLoadedAt)
            SELECT [VendorID], [tpep_pickup_datetime], [tpep_dropoff_datetime], [passenger_count], [trip_distance], [RatecodeID], [store_and_fwd_flag], [PULocationID], [DOLocationID], [payment_type], [fare_amount], [extra], [mta_tax], [tip_amount], [tolls_amount], [improvement_surcharge], [total_amount], [congestion_surcharge], [Airport_fee], [cbd_congestion_fee], @SourceKey, @FileHash, SYSDATETIME() FROM wrk.[YellowTrip];
    END
    ELSE IF @DatasetCode = ''green''
    BEGIN
        SELECT @Count = COUNT_BIG(*) FROM wrk.[GreenTrip];
        IF @Count <> @ExpectedRows OR @RowsLoaded <> @ExpectedRows
            THROW 51003, ''Loaded row count does not match CSV metadata.'', 1;
        DELETE FROM stg.[GreenTrip] WHERE ETLSourceKey = @SourceKey;
        INSERT stg.[GreenTrip] ([VendorID], [lpep_pickup_datetime], [lpep_dropoff_datetime], [store_and_fwd_flag], [RatecodeID], [PULocationID], [DOLocationID], [passenger_count], [trip_distance], [fare_amount], [extra], [mta_tax], [tip_amount], [tolls_amount], [ehail_fee], [improvement_surcharge], [total_amount], [payment_type], [trip_type], [congestion_surcharge], [cbd_congestion_fee], ETLSourceKey, ETLFileHash, ETLLoadedAt)
            SELECT [VendorID], [lpep_pickup_datetime], [lpep_dropoff_datetime], [store_and_fwd_flag], [RatecodeID], [PULocationID], [DOLocationID], [passenger_count], [trip_distance], [fare_amount], [extra], [mta_tax], [tip_amount], [tolls_amount], [ehail_fee], [improvement_surcharge], [total_amount], [payment_type], [trip_type], [congestion_surcharge], [cbd_congestion_fee], @SourceKey, @FileHash, SYSDATETIME() FROM wrk.[GreenTrip];
    END
    ELSE IF @DatasetCode = ''fhv''
    BEGIN
        SELECT @Count = COUNT_BIG(*) FROM wrk.[FHVTrip];
        IF @Count <> @ExpectedRows OR @RowsLoaded <> @ExpectedRows
            THROW 51003, ''Loaded row count does not match CSV metadata.'', 1;
        DELETE FROM stg.[FHVTrip] WHERE ETLSourceKey = @SourceKey;
        INSERT stg.[FHVTrip] ([dispatching_base_num], [pickup_datetime], [dropOff_datetime], [PULocationID], [DOLocationID], [SR_Flag], [Affiliated_base_number], ETLSourceKey, ETLFileHash, ETLLoadedAt)
            SELECT [dispatching_base_num], [pickup_datetime], [dropOff_datetime], [PULocationID], [DOLocationID], [SR_Flag], [Affiliated_base_number], @SourceKey, @FileHash, SYSDATETIME() FROM wrk.[FHVTrip];
    END
    ELSE IF @DatasetCode = ''fhvhv''
    BEGIN
        SELECT @Count = COUNT_BIG(*) FROM wrk.[FHVHVTrip];
        IF @Count <> @ExpectedRows OR @RowsLoaded <> @ExpectedRows
            THROW 51003, ''Loaded row count does not match CSV metadata.'', 1;
        DELETE FROM stg.[FHVHVTrip] WHERE ETLSourceKey = @SourceKey;
        INSERT stg.[FHVHVTrip] ([hvfhs_license_num], [dispatching_base_num], [originating_base_num], [request_datetime], [on_scene_datetime], [pickup_datetime], [dropoff_datetime], [PULocationID], [DOLocationID], [trip_miles], [trip_time], [base_passenger_fare], [tolls], [bcf], [sales_tax], [congestion_surcharge], [airport_fee], [tips], [driver_pay], [shared_request_flag], [shared_match_flag], [access_a_ride_flag], [wav_request_flag], [wav_match_flag], [cbd_congestion_fee], ETLSourceKey, ETLFileHash, ETLLoadedAt)
            SELECT [hvfhs_license_num], [dispatching_base_num], [originating_base_num], [request_datetime], [on_scene_datetime], [pickup_datetime], [dropoff_datetime], [PULocationID], [DOLocationID], [trip_miles], [trip_time], [base_passenger_fare], [tolls], [bcf], [sales_tax], [congestion_surcharge], [airport_fee], [tips], [driver_pay], [shared_request_flag], [shared_match_flag], [access_a_ride_flag], [wav_request_flag], [wav_match_flag], [cbd_congestion_fee], @SourceKey, @FileHash, SYSDATETIME() FROM wrk.[FHVHVTrip];
    END
    ELSE IF @DatasetCode = ''lookup''
    BEGIN
        SELECT @Count = COUNT_BIG(*) FROM wrk.[TaxiZone];
        IF @Count <> @ExpectedRows OR @RowsLoaded <> @ExpectedRows
            THROW 51003, ''Loaded row count does not match CSV metadata.'', 1;
        DELETE FROM stg.[TaxiZone] WHERE ETLSourceKey = @SourceKey;
        INSERT stg.[TaxiZone] ([LocationID], [Borough], [Zone], [service_zone], ETLSourceKey, ETLFileHash, ETLLoadedAt)
            SELECT [LocationID], [Borough], [Zone], [service_zone], @SourceKey, @FileHash, SYSDATETIME() FROM wrk.[TaxiZone];
    END
    ELSE THROW 51005, ''Unknown dataset.'', 1;
        UPDATE etl.ExtractFileLog SET FilePath = @FilePath, FileHash = @FileHash,
            RowLimit = @RowLimit, ExpectedRows = @ExpectedRows, RowsLoaded = @RowsLoaded,
            LoadStatus = ''SUCCEEDED'', CompletedAt = SYSDATETIME(), ErrorMessage = NULL
        WHERE DatasetCode = @DatasetCode AND SourceKey = @SourceKey;
        IF @@ROWCOUNT <> 1 THROW 51006, ''No matching file load record.'', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;');

EXEC(N'IF EXISTS (SELECT 1 FROM stg.[YellowTrip] WHERE ETLSourceKey IS NULL) THROW 51008, ''Existing rows in stg.YellowTrip have no source lineage. Archive or establish an empty staging baseline before the first refactored load.'', 1;');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'stg.YellowTrip') AND name = N'IX_ExtractSourceKey')
    EXEC(N'CREATE INDEX IX_ExtractSourceKey ON stg.[YellowTrip] (ETLSourceKey) INCLUDE (ETLFileHash);');

EXEC(N'IF EXISTS (SELECT 1 FROM stg.[GreenTrip] WHERE ETLSourceKey IS NULL) THROW 51008, ''Existing rows in stg.GreenTrip have no source lineage. Archive or establish an empty staging baseline before the first refactored load.'', 1;');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'stg.GreenTrip') AND name = N'IX_ExtractSourceKey')
    EXEC(N'CREATE INDEX IX_ExtractSourceKey ON stg.[GreenTrip] (ETLSourceKey) INCLUDE (ETLFileHash);');

EXEC(N'IF EXISTS (SELECT 1 FROM stg.[FHVTrip] WHERE ETLSourceKey IS NULL) THROW 51008, ''Existing rows in stg.FHVTrip have no source lineage. Archive or establish an empty staging baseline before the first refactored load.'', 1;');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'stg.FHVTrip') AND name = N'IX_ExtractSourceKey')
    EXEC(N'CREATE INDEX IX_ExtractSourceKey ON stg.[FHVTrip] (ETLSourceKey) INCLUDE (ETLFileHash);');

EXEC(N'IF EXISTS (SELECT 1 FROM stg.[FHVHVTrip] WHERE ETLSourceKey IS NULL) THROW 51008, ''Existing rows in stg.FHVHVTrip have no source lineage. Archive or establish an empty staging baseline before the first refactored load.'', 1;');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'stg.FHVHVTrip') AND name = N'IX_ExtractSourceKey')
    EXEC(N'CREATE INDEX IX_ExtractSourceKey ON stg.[FHVHVTrip] (ETLSourceKey) INCLUDE (ETLFileHash);');

EXEC(N'IF EXISTS (SELECT 1 FROM stg.[TaxiZone] WHERE ETLSourceKey IS NULL) THROW 51008, ''Existing rows in stg.TaxiZone have no source lineage. Archive or establish an empty staging baseline before the first refactored load.'', 1;');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'stg.TaxiZone') AND name = N'IX_ExtractSourceKey')
    EXEC(N'CREATE INDEX IX_ExtractSourceKey ON stg.[TaxiZone] (ETLSourceKey) INCLUDE (ETLFileHash);');
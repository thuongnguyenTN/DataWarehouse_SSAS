SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Dataset VARCHAR(20)='yellow', @TaxiType VARCHAR(10)='YELLOW',
        @RuleVersion VARCHAR(64)='INCR_20261019_1|hours=48', @MaxDurationHours INT=48,
        @ZoneText NVARCHAR(MAX), @ZoneHash CHAR(64);

DROP TABLE IF EXISTS #Files;
DROP TABLE IF EXISTS #CleanCounts;
DROP TABLE IF EXISTS #Todo;
DROP TABLE IF EXISTS #StageCounts;
DROP TABLE IF EXISTS #Result;

BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM clean.TaxiZone WITH(HOLDLOCK))
        THROW 51220, 'Chay task lookup truoc.', 1;
    IF EXISTS(SELECT 1 FROM clean.Trip WITH(UPDLOCK,HOLDLOCK)
        WHERE TaxiType=@TaxiType AND ETLSourceKey IS NULL)
        THROW 51221, 'Clean cu thieu ETLSourceKey; can chuan hoa lineage truoc.', 1;
    IF EXISTS(SELECT 1 FROM stg.YellowTrip WITH(HOLDLOCK) WHERE ETLSourceKey IS NULL)
        THROW 51222, 'Staging thieu lineage. Dung PKG_01 moi.', 1;

SELECT @ZoneText=CONVERT(NVARCHAR(MAX),
    (SELECT LocationID,Borough,Zone,ServiceZone
     FROM clean.TaxiZone WITH(HOLDLOCK)
     ORDER BY LocationID FOR XML RAW('z'),TYPE));
SET @ZoneHash=CONVERT(CHAR(64),HASHBYTES('SHA2_256',@ZoneText),2);

    /* 1. Cac tep Extract da nap thanh cong. Khong chuyen kieu du lieu o buoc nay. */
    SELECT SourceKey,FileHash,ExpectedRows
    INTO #Files
    FROM etl.ExtractFileLog WITH(UPDLOCK,HOLDLOCK)
    WHERE DatasetCode=@Dataset AND LoadStatus='SUCCEEDED' AND RowsLoaded=ExpectedRows;

    /* 2. Kiem tra so dong/hash clean thuc te bang index theo tep. */
    SELECT t.ETLSourceKey AS SourceKey,COUNT_BIG(*) AS CleanRows,
        COUNT_BIG(CASE WHEN t.ETLFileHash IS NULL OR t.ETLFileHash<>f.FileHash THEN 1 END) AS BadHashRows
    INTO #CleanCounts
    FROM clean.Trip AS t WITH(HOLDLOCK)
    INNER JOIN #Files AS f ON f.SourceKey=t.ETLSourceKey
    WHERE t.TaxiType=@TaxiType
    GROUP BY t.ETLSourceKey;

    /* 3. Chi chon tep chua lam, tep thay doi, hoac clean bi thieu. */
SELECT f.SourceKey,f.FileHash,f.ExpectedRows
INTO #Todo
FROM #Files AS f
LEFT JOIN #CleanCounts AS c ON c.SourceKey=f.SourceKey
LEFT JOIN etl.TransformFileLog AS l WITH(UPDLOCK,HOLDLOCK)
    ON l.DatasetCode=@Dataset AND l.SourceKey=f.SourceKey
WHERE l.SourceKey IS NULL
    OR l.FileHash<>f.FileHash
    OR l.SourceRows<>f.ExpectedRows OR l.CleanRows<>f.ExpectedRows
    OR l.RuleVersion<>@RuleVersion OR l.ZoneHash<>@ZoneHash
    OR COALESCE(c.CleanRows,0)<>f.ExpectedRows
    OR COALESCE(c.BadHashRows,0)>0;
    CREATE UNIQUE CLUSTERED INDEX IX_Todo_Source ON #Todo(SourceKey);

    IF EXISTS(SELECT 1 FROM #Todo)
    BEGIN
    /* 4. Kiem tra staging cua DUNG cac tep can xu ly truoc khi sua clean. */
    SELECT s.ETLSourceKey AS SourceKey,COUNT_BIG(*) AS SourceRows,
        COUNT_BIG(CASE WHEN s.ETLFileHash IS NULL OR s.ETLFileHash<>f.FileHash THEN 1 END) AS BadHashRows
    INTO #StageCounts
    FROM stg.YellowTrip AS s WITH(HOLDLOCK)
    INNER JOIN #Todo AS f ON f.SourceKey=s.ETLSourceKey
    GROUP BY s.ETLSourceKey;

    IF EXISTS(SELECT 1 FROM #Todo AS f LEFT JOIN #StageCounts AS s ON s.SourceKey=f.SourceKey
        WHERE COALESCE(s.SourceRows,0)<>f.ExpectedRows OR COALESCE(s.BadHashRows,0)>0)
        THROW 51223, 'Staging cua tep can Transform khong khop log. Chay lai PKG_01.', 1;

    /* 5. Giu nguyen cac tep da hoan tat; chi thay the cac tep trong #Todo. */
    DELETE t FROM clean.Trip AS t
    INNER JOIN #Todo AS f ON f.SourceKey=t.ETLSourceKey
    WHERE t.TaxiType=@TaxiType;

;WITH S AS
(
    SELECT
        TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM([tpep_pickup_datetime])), '')) AS PickupDateTime,
        TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM([tpep_dropoff_datetime])), '')) AS DropoffDateTime,
        TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM([PULocationID])), '')) AS PULocationID,
        TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM([DOLocationID])), '')) AS DOLocationID,
        TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM([VendorID])), '')) AS VendorID,
        TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM([passenger_count])), '')) AS PassengerCount,
        TRY_CONVERT(DECIMAL(12,3), NULLIF(LTRIM(RTRIM([trip_distance])), '')) AS TripDistanceMiles,
        TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM([RatecodeID])), '')) AS RateCodeID,
        TRY_CONVERT(DECIMAL(38,18), NULLIF(LTRIM(RTRIM([payment_type])), '')) AS PaymentTypeID,
        CASE WHEN UPPER(NULLIF(LTRIM(RTRIM([store_and_fwd_flag])), '')) IN ('Y','1','TRUE') THEN 'Y' WHEN UPPER(NULLIF(LTRIM(RTRIM([store_and_fwd_flag])), '')) IN ('N','0','FALSE') THEN 'N' END AS StoreAndFwdFlag,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([fare_amount])), '')) AS FareAmount,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([extra])), '')) AS ExtraAmount,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([mta_tax])), '')) AS MTATaxAmount,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([tip_amount])), '')) AS TipAmount,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([tolls_amount])), '')) AS TollsAmount,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([improvement_surcharge])), '')) AS ImprovementSurcharge,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([congestion_surcharge])), '')) AS CongestionSurcharge,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([cbd_congestion_fee])), '')) AS CBDCongestionFee,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([total_amount])), '')) AS TotalAmount,
        TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM([Airport_fee])), '')) AS AirportFee,
        ETLSourceKey,
        ETLFileHash,
        ETLLoadedAt
    FROM stg.YellowTrip AS s WITH(HOLDLOCK)
    INNER JOIN #Todo AS f ON f.SourceKey=s.ETLSourceKey
)
INSERT INTO clean.Trip
(
    TaxiType, PickupDateTime, DropoffDateTime, PULocationID, DOLocationID, VendorID, PassengerCount, TripDistanceMiles, RateCodeID, PaymentTypeID, StoreAndFwdFlag, FareAmount, ExtraAmount, MTATaxAmount, TipAmount, TollsAmount, ImprovementSurcharge, CongestionSurcharge, CBDCongestionFee, TotalAmount, AirportFee, TripDurationSeconds, IsTotalCalculated, IsCoreValid, ETLSourceKey, ETLFileHash, ETLLoadedAt
)
SELECT
    'YELLOW',
    PickupDateTime,
    DropoffDateTime,
    CASE WHEN PULocationID = FLOOR(PULocationID) THEN TRY_CONVERT(INT, PULocationID) END,
    CASE WHEN DOLocationID = FLOOR(DOLocationID) THEN TRY_CONVERT(INT, DOLocationID) END,
    CASE WHEN VendorID = FLOOR(VendorID) THEN TRY_CONVERT(INT, VendorID) END,
    CASE WHEN PassengerCount = FLOOR(PassengerCount) THEN TRY_CONVERT(INT, PassengerCount) END,
    TripDistanceMiles,
    CASE WHEN RateCodeID = FLOOR(RateCodeID) THEN TRY_CONVERT(INT, RateCodeID) END,
    CASE WHEN PaymentTypeID = FLOOR(PaymentTypeID) THEN TRY_CONVERT(INT, PaymentTypeID) END,
    StoreAndFwdFlag,
    FareAmount,
    ExtraAmount,
    MTATaxAmount,
    TipAmount,
    TollsAmount,
    ImprovementSurcharge,
    CongestionSurcharge,
    CBDCongestionFee,
    TotalAmount,
    AirportFee,
    DATEDIFF_BIG(SECOND, PickupDateTime, DropoffDateTime),
    0,
    0,
    ETLSourceKey,
    ETLFileHash,
    ETLLoadedAt
FROM S;

    /* 6. Chi tinh do do/gan loi cho cac tep vua nap. */
UPDATE t
SET
    TripDistanceKm = TRY_CONVERT(DECIMAL(14,3), t.TripDistanceMiles * 1.609344),
    AverageSpeedKmh = CASE WHEN t.TripDurationSeconds > 0 AND t.TripDistanceMiles >= 0
        THEN TRY_CONVERT(DECIMAL(14,3), t.TripDistanceMiles * 1.609344 * 3600.0
            / NULLIF(t.TripDurationSeconds, 0)) END,
    RequestWaitSeconds = CASE WHEN t.RequestDateTime <= t.PickupDateTime
        THEN DATEDIFF_BIG(SECOND, t.RequestDateTime, t.PickupDateTime) END,
    IsCoreValid = CASE
        WHEN t.PickupDateTime IS NULL OR t.DropoffDateTime IS NULL
          OR t.DropoffDateTime <= t.PickupDateTime
          OR t.TripDurationSeconds > CONVERT(BIGINT, @MaxDurationHours) * 3600
          OR (t.TaxiType <> 'FHV' AND (t.TripDistanceMiles IS NULL OR t.TripDistanceMiles < 0))
        THEN 0 ELSE 1 END,
    QualityIssue = NULLIF(CONCAT(
        CASE WHEN t.PickupDateTime IS NULL THEN 'PICKUP_INVALID;' ELSE '' END,
        CASE WHEN t.DropoffDateTime IS NULL THEN 'DROPOFF_INVALID;' ELSE '' END,
        CASE WHEN t.DropoffDateTime <= t.PickupDateTime THEN 'DURATION_NON_POSITIVE;' ELSE '' END,
        CASE WHEN t.TripDurationSeconds > CONVERT(BIGINT, @MaxDurationHours) * 3600 THEN 'DURATION_OVER_LIMIT;' ELSE '' END,
        CASE WHEN t.TaxiType <> 'FHV' AND t.TripDistanceMiles IS NULL THEN 'DISTANCE_MISSING;' ELSE '' END,
        CASE WHEN t.TripDistanceMiles < 0 THEN 'DISTANCE_NEGATIVE;' ELSE '' END,
        CASE WHEN t.TripDistanceMiles = 0 THEN 'DISTANCE_ZERO;' ELSE '' END,
        CASE WHEN t.TaxiType IN ('YELLOW','GREEN') AND (t.PassengerCount IS NULL OR t.PassengerCount <= 0) THEN 'PASSENGER_INVALID;' ELSE '' END,
        CASE WHEN pu.LocationID IS NULL THEN 'PU_LOCATION_UNKNOWN;' ELSE '' END,
        CASE WHEN dz.LocationID IS NULL THEN 'DO_LOCATION_UNKNOWN;' ELSE '' END,
        CASE WHEN t.TotalAmount < 0 THEN 'TOTAL_NEGATIVE;' ELSE '' END,
        CASE WHEN t.TaxiType <> 'FHV' AND t.TotalAmount IS NULL THEN 'TOTAL_MISSING;' ELSE '' END,
        CASE WHEN t.TaxiType = 'FHVHV' AND t.RequestDateTime IS NULL THEN 'REQUEST_MISSING;' ELSE '' END,
        CASE WHEN t.RequestDateTime > t.PickupDateTime THEN 'REQUEST_AFTER_PICKUP;' ELSE '' END,
        CASE WHEN t.OnSceneDateTime > t.PickupDateTime THEN 'ONSCENE_AFTER_PICKUP;' ELSE '' END,
        CASE WHEN ABS(CONVERT(DECIMAL(38,0), t.SourceTripDurationSeconds) - t.TripDurationSeconds) > 60
            THEN 'SOURCE_DURATION_MISMATCH;' ELSE '' END
    ), '')
FROM clean.Trip AS t
INNER JOIN #Todo AS scope ON scope.SourceKey=t.ETLSourceKey
LEFT JOIN clean.TaxiZone AS pu ON pu.LocationID = t.PULocationID
LEFT JOIN clean.TaxiZone AS dz ON dz.LocationID = t.DOLocationID
WHERE t.TaxiType=@TaxiType;

    /* 7. Doi soat va ghi log trong CUNG transaction voi du lieu clean. */
    SELECT t.ETLSourceKey AS SourceKey,COUNT_BIG(*) AS CleanRows,
        COUNT_BIG(CASE WHEN t.IsCoreValid=1 THEN 1 END) AS ValidRows,
        COUNT_BIG(CASE WHEN t.IsCoreValid=0 THEN 1 END) AS RejectedRows,
        COUNT_BIG(CASE WHEN t.IsCoreValid=1 AND t.QualityIssue IS NOT NULL THEN 1 END) AS WarningRows
    INTO #Result
    FROM clean.Trip AS t
    INNER JOIN #Todo AS f ON f.SourceKey=t.ETLSourceKey
    WHERE t.TaxiType=@TaxiType
    GROUP BY t.ETLSourceKey;

    IF EXISTS(SELECT 1 FROM #Todo AS f LEFT JOIN #Result AS r ON r.SourceKey=f.SourceKey
        WHERE COALESCE(r.CleanRows,0)<>f.ExpectedRows
            OR COALESCE(r.ValidRows,0)+COALESCE(r.RejectedRows,0)<>f.ExpectedRows)
        THROW 51224, 'So dong sau Transform khong khop. Rollback tep dang xu ly.', 1;

    DELETE l FROM etl.TransformFileLog AS l
    INNER JOIN #Todo AS f ON f.SourceKey=l.SourceKey
    WHERE l.DatasetCode=@Dataset;

    INSERT etl.TransformFileLog
        (DatasetCode,SourceKey,FileHash,RuleVersion,ZoneHash,SourceRows,
         CleanRows,ValidRows,RejectedRows,WarningRows,CompletedAt)
    SELECT @Dataset,f.SourceKey,f.FileHash,@RuleVersion,@ZoneHash,f.ExpectedRows,
        COALESCE(r.CleanRows,0),COALESCE(r.ValidRows,0),COALESCE(r.RejectedRows,0),
        COALESCE(r.WarningRows,0),SYSDATETIME()
    FROM #Todo AS f LEFT JOIN #Result AS r ON r.SourceKey=f.SourceKey;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT @Dataset AS DatasetCode,
    (SELECT COUNT(*) FROM #Todo) AS ProcessedFiles,
    (SELECT COUNT(*) FROM #Files)-(SELECT COUNT(*) FROM #Todo) AS SkippedFiles;

DROP TABLE IF EXISTS #Files;
DROP TABLE IF EXISTS #CleanCounts;
DROP TABLE IF EXISTS #Todo;
DROP TABLE IF EXISTS #StageCounts;
DROP TABLE IF EXISTS #Result;

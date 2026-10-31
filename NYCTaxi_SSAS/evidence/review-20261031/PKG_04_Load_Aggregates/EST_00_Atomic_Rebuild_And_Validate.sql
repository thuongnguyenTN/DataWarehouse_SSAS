SET XACT_ABORT ON; BEGIN TRY BEGIN TRANSACTION;
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_ID(N'NYCTaxi_DWH') IS NULL
    THROW 54001, 'NYCTaxi_DWH does not exist', 1;
IF OBJECT_ID(N'dbo.Fact_YellowGreen_Trips', N'U') IS NULL
 OR OBJECT_ID(N'dbo.Fact_FHV_Trips', N'U') IS NULL
 OR OBJECT_ID(N'dbo.Fact_HVFHV_Trips', N'U') IS NULL
    THROW 54002, 'Transactional facts are missing', 1;
IF OBJECT_ID(N'dbo.Fact_Daily_Financial_Snapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Fact_Daily_Financial_Snapshot
    (
        DateKey INT NOT NULL,
        ServiceTypeKey INT NOT NULL,
        TotalTrips BIGINT NOT NULL,
        TotalDistanceMiles DECIMAL(24,3) NULL,
        TotalPassengerCharges DECIMAL(28,2) NULL,
        TotalTips DECIMAL(28,2) NULL,
        TotalTaxesAndFees DECIMAL(28,2) NULL,
        TotalDriverPay DECIMAL(28,2) NULL,
        SnapshotUpdatedAt DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_Fact_Daily_Financial_Snapshot PRIMARY KEY (DateKey, ServiceTypeKey),
        CONSTRAINT FK_DFS_Date FOREIGN KEY (DateKey) REFERENCES dbo.Dim_Date(DateKey),
        CONSTRAINT FK_DFS_Service FOREIGN KEY (ServiceTypeKey) REFERENCES dbo.Dim_ServiceType(ServiceTypeKey)
    );
END;
IF OBJECT_ID(N'dbo.Fact_Zone_Traffic_Snapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Fact_Zone_Traffic_Snapshot
    (
        DateKey INT NOT NULL,
        TimeKey SMALLINT NOT NULL,
        LocationKey INT NOT NULL,
        ServiceTypeKey INT NOT NULL,
        TotalPickups BIGINT NOT NULL,
        TotalDropoffs BIGINT NOT NULL,
        SnapshotUpdatedAt DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_Fact_Zone_Traffic_Snapshot PRIMARY KEY (DateKey, TimeKey, LocationKey, ServiceTypeKey),
        CONSTRAINT FK_ZTS_Date FOREIGN KEY (DateKey) REFERENCES dbo.Dim_Date(DateKey),
        CONSTRAINT FK_ZTS_Time FOREIGN KEY (TimeKey) REFERENCES dbo.Dim_Time(TimeKey),
        CONSTRAINT FK_ZTS_Location FOREIGN KEY (LocationKey) REFERENCES dbo.Dim_Location(LocationKey),
        CONSTRAINT FK_ZTS_Service FOREIGN KEY (ServiceTypeKey) REFERENCES dbo.Dim_ServiceType(ServiceTypeKey)
    );
END;
IF OBJECT_ID(N'dbo.Fact_Base_Performance_Snapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Fact_Base_Performance_Snapshot
    (
        DateKey INT NOT NULL,
        DispatchBaseKey INT NOT NULL,
        ServiceTypeKey INT NOT NULL,
        HVFHSProviderKey INT NOT NULL,
        TotalTrips BIGINT NOT NULL,
        TotalTripDurationSeconds BIGINT NULL,
        DurationTripCount BIGINT NOT NULL,
        AverageTripDurationSeconds DECIMAL(18,2) NULL,
        TotalWaitingTimeSeconds BIGINT NULL,
        WaitingTripCount BIGINT NOT NULL,
        AverageWaitingTimeSeconds DECIMAL(18,2) NULL,
        TotalSharedRequests BIGINT NULL,
        TotalSharedMatches BIGINT NULL,
        TotalWAVRequests BIGINT NULL,
        TotalWAVMatches BIGINT NULL,
        TotalDriverPay DECIMAL(28,2) NULL,
        SnapshotUpdatedAt DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_Fact_Base_Performance_Snapshot PRIMARY KEY (DateKey, DispatchBaseKey, ServiceTypeKey, HVFHSProviderKey),
        CONSTRAINT FK_BPS_Date FOREIGN KEY (DateKey) REFERENCES dbo.Dim_Date(DateKey),
        CONSTRAINT FK_BPS_Base FOREIGN KEY (DispatchBaseKey) REFERENCES dbo.Dim_Base(BaseKey),
        CONSTRAINT FK_BPS_Service FOREIGN KEY (ServiceTypeKey) REFERENCES dbo.Dim_ServiceType(ServiceTypeKey),
        CONSTRAINT FK_BPS_Provider FOREIGN KEY (HVFHSProviderKey) REFERENCES dbo.Dim_HVFHSProvider(HVFHSProviderKey)
    );
END;

BEGIN TRY
BEGIN TRANSACTION;
IF NOT EXISTS(SELECT 1 FROM sys.schemas WHERE name=N'etl')
    EXEC(N'CREATE SCHEMA etl AUTHORIZATION dbo');
IF OBJECT_ID(N'etl.AggregateWatermark',N'U') IS NULL
    CREATE TABLE etl.AggregateWatermark
    (
       AggregateName varchar(50) NOT NULL,
       FactName varchar(50) NOT NULL,
       LastTripKey bigint NOT NULL DEFAULT 0,
       UpdatedAt datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
       CONSTRAINT PK_AggregateWatermark PRIMARY KEY (AggregateName,FactName)
    );
-- If a snapshot already exists from the prior full-refresh package,
-- rebuild it ONCE from all facts, without touching transactional rows.
IF NOT EXISTS(SELECT 1 FROM etl.AggregateWatermark WHERE AggregateName='DailyFinancial')
BEGIN
  DELETE FROM dbo.Fact_Daily_Financial_Snapshot;
  INSERT etl.AggregateWatermark(AggregateName,FactName,LastTripKey)
  VALUES('DailyFinancial','YellowGreen',0),('DailyFinancial','HVFHV',0);
END;
IF NOT EXISTS(SELECT 1 FROM etl.AggregateWatermark WHERE AggregateName='ZoneTraffic')
BEGIN
  DELETE FROM dbo.Fact_Zone_Traffic_Snapshot;
  INSERT etl.AggregateWatermark(AggregateName,FactName,LastTripKey)
  VALUES('ZoneTraffic','YellowGreen',0),('ZoneTraffic','FHV',0),('ZoneTraffic','HVFHV',0);
END;
IF NOT EXISTS(SELECT 1 FROM etl.AggregateWatermark WHERE AggregateName='BasePerformance')
BEGIN
  DELETE FROM dbo.Fact_Base_Performance_Snapshot;
  INSERT etl.AggregateWatermark(AggregateName,FactName,LastTripKey)
  VALUES('BasePerformance','FHV',0),('BasePerformance','HVFHV',0);
END;
IF (SELECT COUNT(*) FROM etl.AggregateWatermark WHERE AggregateName='DailyFinancial')<>2
 OR (SELECT COUNT(*) FROM etl.AggregateWatermark WHERE AggregateName='ZoneTraffic')<>3
 OR (SELECT COUNT(*) FROM etl.AggregateWatermark WHERE AggregateName='BasePerformance')<>2
 THROW 55211,'AggregateWatermark has an incomplete state; inspect before loading.',1;
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;

DELETE FROM dbo.Fact_Daily_Financial_Snapshot; DELETE FROM dbo.Fact_Zone_Traffic_Snapshot; DELETE FROM dbo.Fact_Base_Performance_Snapshot; UPDATE etl.AggregateWatermark SET LastTripKey=0,UpdatedAt=SYSDATETIME();
EXEC sys.sp_executesql N'SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @YellowGreenPrev bigint = (SELECT LastTripKey FROM etl.AggregateWatermark WITH (UPDLOCK,HOLDLOCK) WHERE AggregateName=''DailyFinancial'' AND FactName=''YellowGreen'');
 DECLARE @YellowGreenMax bigint = ISNULL((SELECT MAX(TripKey) FROM dbo.Fact_YellowGreen_Trips),0);
 IF @YellowGreenPrev IS NULL OR @YellowGreenMax < @YellowGreenPrev THROW 55101, ''Missing watermark or transactional Fact keys reset; manual rebuild required.'',1;
 DECLARE @HVFHVPrev bigint = (SELECT LastTripKey FROM etl.AggregateWatermark WITH (UPDLOCK,HOLDLOCK) WHERE AggregateName=''DailyFinancial'' AND FactName=''HVFHV'');
 DECLARE @HVFHVMax bigint = ISNULL((SELECT MAX(TripKey) FROM dbo.Fact_HVFHV_Trips),0);
 IF @HVFHVPrev IS NULL OR @HVFHVMax < @HVFHVPrev THROW 55101, ''Missing watermark or transactional Fact keys reset; manual rebuild required.'',1;
;WITH FinancialSource AS
    (
        SELECT
            PickupDateKey AS DateKey, ServiceTypeKey,
            CONVERT(BIGINT, TripCount) AS Trips,
            CONVERT(DECIMAL(28,3), TripDistanceMiles) AS DistanceMiles,
            CONVERT(DECIMAL(28,2), TotalAmount) AS PassengerCharges,
            CONVERT(DECIMAL(28,2), TipAmount) AS Tips,
            CASE WHEN ExtraAmount IS NULL AND MTATaxAmount IS NULL
                   AND ImprovementSurcharge IS NULL AND CongestionSurcharge IS NULL
                   AND AirportFee IS NULL AND CBDCongestionFee IS NULL
                 THEN CAST(NULL AS DECIMAL(28,2))
                 ELSE CONVERT(DECIMAL(28,2),
                   COALESCE(ExtraAmount, 0) + COALESCE(MTATaxAmount, 0)
                   + COALESCE(ImprovementSurcharge, 0) + COALESCE(CongestionSurcharge, 0)
                   + COALESCE(AirportFee, 0) + COALESCE(CBDCongestionFee, 0)) END AS TaxesAndFees,
            CAST(NULL AS DECIMAL(28,2)) AS DriverPay
        FROM dbo.Fact_YellowGreen_Trips WHERE TripKey>@YellowGreenPrev AND TripKey<=@YellowGreenMax
        UNION ALL
        SELECT PickupDateKey, ServiceTypeKey,
            CONVERT(BIGINT, TripCount),
            CONVERT(DECIMAL(28,3), TripDistanceMiles),
            CONVERT(DECIMAL(28,2), GrossPassengerAmount),
            CONVERT(DECIMAL(28,2), TipAmount),
            CASE WHEN BCFAmount IS NULL AND SalesTaxAmount IS NULL
                   AND CongestionSurcharge IS NULL AND AirportFee IS NULL
                   AND CBDCongestionFee IS NULL
                 THEN CAST(NULL AS DECIMAL(28,2))
                 ELSE CONVERT(DECIMAL(28,2), COALESCE(BCFAmount, 0)
                    + COALESCE(SalesTaxAmount, 0) + COALESCE(CongestionSurcharge, 0)
                    + COALESCE(AirportFee, 0) + COALESCE(CBDCongestionFee, 0)) END,
            CONVERT(DECIMAL(28,2), DriverPayAmount)
        FROM dbo.Fact_HVFHV_Trips WHERE TripKey>@HVFHVPrev AND TripKey<=@HVFHVMax
    )

 SELECT DateKey,ServiceTypeKey,
        SUM(Trips) AS TotalTrips, SUM(DistanceMiles) AS TotalDistanceMiles,
        SUM(PassengerCharges) AS TotalPassengerCharges,SUM(Tips) AS TotalTips,
        SUM(TaxesAndFees) AS TotalTaxesAndFees,SUM(DriverPay) AS TotalDriverPay
 INTO #Delta FROM FinancialSource GROUP BY DateKey,ServiceTypeKey;

 UPDATE T SET
    T.TotalTrips=T.TotalTrips+S.TotalTrips,
    T.TotalDistanceMiles=CASE WHEN T.TotalDistanceMiles IS NULL AND S.TotalDistanceMiles IS NULL THEN NULL ELSE COALESCE(T.TotalDistanceMiles,0)+COALESCE(S.TotalDistanceMiles,0) END,
    T.TotalPassengerCharges=CASE WHEN T.TotalPassengerCharges IS NULL AND S.TotalPassengerCharges IS NULL THEN NULL ELSE COALESCE(T.TotalPassengerCharges,0)+COALESCE(S.TotalPassengerCharges,0) END,
    T.TotalTips=CASE WHEN T.TotalTips IS NULL AND S.TotalTips IS NULL THEN NULL ELSE COALESCE(T.TotalTips,0)+COALESCE(S.TotalTips,0) END,
    T.TotalTaxesAndFees=CASE WHEN T.TotalTaxesAndFees IS NULL AND S.TotalTaxesAndFees IS NULL THEN NULL ELSE COALESCE(T.TotalTaxesAndFees,0)+COALESCE(S.TotalTaxesAndFees,0) END,
    T.TotalDriverPay=CASE WHEN T.TotalDriverPay IS NULL AND S.TotalDriverPay IS NULL THEN NULL ELSE COALESCE(T.TotalDriverPay,0)+COALESCE(S.TotalDriverPay,0) END,
    T.SnapshotUpdatedAt=SYSDATETIME()
 FROM dbo.Fact_Daily_Financial_Snapshot T JOIN #Delta S ON T.DateKey=S.DateKey AND T.ServiceTypeKey=S.ServiceTypeKey;
 INSERT dbo.Fact_Daily_Financial_Snapshot(DateKey, ServiceTypeKey, TotalTrips, TotalDistanceMiles, TotalPassengerCharges, TotalTips, TotalTaxesAndFees, TotalDriverPay)
 SELECT S.DateKey, S.ServiceTypeKey, S.TotalTrips, S.TotalDistanceMiles, S.TotalPassengerCharges, S.TotalTips, S.TotalTaxesAndFees, S.TotalDriverPay
 FROM #Delta S WHERE NOT EXISTS(SELECT 1 FROM dbo.Fact_Daily_Financial_Snapshot T WITH(UPDLOCK,HOLDLOCK) WHERE T.DateKey=S.DateKey AND T.ServiceTypeKey=S.ServiceTypeKey);
 UPDATE etl.AggregateWatermark SET LastTripKey=@YellowGreenMax,UpdatedAt=SYSDATETIME() WHERE AggregateName=''DailyFinancial'' AND FactName=''YellowGreen'';
UPDATE etl.AggregateWatermark SET LastTripKey=@HVFHVMax,UpdatedAt=SYSDATETIME() WHERE AggregateName=''DailyFinancial'' AND FactName=''HVFHV'';
 COMMIT TRAN;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
';
EXEC sys.sp_executesql N'SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @YellowGreenPrev bigint = (SELECT LastTripKey FROM etl.AggregateWatermark WITH (UPDLOCK,HOLDLOCK) WHERE AggregateName=''ZoneTraffic'' AND FactName=''YellowGreen'');
 DECLARE @YellowGreenMax bigint = ISNULL((SELECT MAX(TripKey) FROM dbo.Fact_YellowGreen_Trips),0);
 IF @YellowGreenPrev IS NULL OR @YellowGreenMax < @YellowGreenPrev THROW 55101, ''Missing watermark or transactional Fact keys reset; manual rebuild required.'',1;
 DECLARE @FHVPrev bigint = (SELECT LastTripKey FROM etl.AggregateWatermark WITH (UPDLOCK,HOLDLOCK) WHERE AggregateName=''ZoneTraffic'' AND FactName=''FHV'');
 DECLARE @FHVMax bigint = ISNULL((SELECT MAX(TripKey) FROM dbo.Fact_FHV_Trips),0);
 IF @FHVPrev IS NULL OR @FHVMax < @FHVPrev THROW 55101, ''Missing watermark or transactional Fact keys reset; manual rebuild required.'',1;
 DECLARE @HVFHVPrev bigint = (SELECT LastTripKey FROM etl.AggregateWatermark WITH (UPDLOCK,HOLDLOCK) WHERE AggregateName=''ZoneTraffic'' AND FactName=''HVFHV'');
 DECLARE @HVFHVMax bigint = ISNULL((SELECT MAX(TripKey) FROM dbo.Fact_HVFHV_Trips),0);
 IF @HVFHVPrev IS NULL OR @HVFHVMax < @HVFHVPrev THROW 55101, ''Missing watermark or transactional Fact keys reset; manual rebuild required.'',1;
;WITH ZoneEvents AS
    (
        SELECT PickupDateKey AS DateKey, PickupTimeKey AS TimeKey,
               PickupLocationKey AS LocationKey, ServiceTypeKey,
               CONVERT(BIGINT, TripCount) AS Pickups, CONVERT(BIGINT,0) AS Dropoffs
        FROM dbo.Fact_YellowGreen_Trips WHERE TripKey>@YellowGreenPrev AND TripKey<=@YellowGreenMax
        UNION ALL
        SELECT DropoffDateKey, DropoffTimeKey, DropoffLocationKey, ServiceTypeKey,
               CONVERT(BIGINT,0), CONVERT(BIGINT, TripCount)
        FROM dbo.Fact_YellowGreen_Trips WHERE TripKey>@YellowGreenPrev AND TripKey<=@YellowGreenMax
        UNION ALL
        SELECT PickupDateKey, PickupTimeKey, PickupLocationKey, ServiceTypeKey,
               CONVERT(BIGINT, TripCount), CONVERT(BIGINT,0)
        FROM dbo.Fact_FHV_Trips WHERE TripKey>@FHVPrev AND TripKey<=@FHVMax
        UNION ALL
        SELECT DropoffDateKey, DropoffTimeKey, DropoffLocationKey, ServiceTypeKey,
               CONVERT(BIGINT,0), CONVERT(BIGINT, TripCount)
        FROM dbo.Fact_FHV_Trips WHERE TripKey>@FHVPrev AND TripKey<=@FHVMax
        UNION ALL
        SELECT PickupDateKey, PickupTimeKey, PickupLocationKey, ServiceTypeKey,
               CONVERT(BIGINT, TripCount), CONVERT(BIGINT,0)
        FROM dbo.Fact_HVFHV_Trips WHERE TripKey>@HVFHVPrev AND TripKey<=@HVFHVMax
        UNION ALL
        SELECT DropoffDateKey, DropoffTimeKey, DropoffLocationKey, ServiceTypeKey,
               CONVERT(BIGINT,0), CONVERT(BIGINT, TripCount)
        FROM dbo.Fact_HVFHV_Trips WHERE TripKey>@HVFHVPrev AND TripKey<=@HVFHVMax
    )

 SELECT DateKey,TimeKey,LocationKey,ServiceTypeKey,
        SUM(Pickups) AS TotalPickups,SUM(Dropoffs) AS TotalDropoffs
 INTO #Delta FROM ZoneEvents GROUP BY DateKey,TimeKey,LocationKey,ServiceTypeKey;

 UPDATE T SET
    T.TotalPickups=T.TotalPickups+S.TotalPickups,
    T.TotalDropoffs=T.TotalDropoffs+S.TotalDropoffs,
    T.SnapshotUpdatedAt=SYSDATETIME()
 FROM dbo.Fact_Zone_Traffic_Snapshot T JOIN #Delta S ON T.DateKey=S.DateKey AND T.TimeKey=S.TimeKey AND T.LocationKey=S.LocationKey AND T.ServiceTypeKey=S.ServiceTypeKey;
 INSERT dbo.Fact_Zone_Traffic_Snapshot(DateKey, TimeKey, LocationKey, ServiceTypeKey, TotalPickups, TotalDropoffs)
 SELECT S.DateKey, S.TimeKey, S.LocationKey, S.ServiceTypeKey, S.TotalPickups, S.TotalDropoffs
 FROM #Delta S WHERE NOT EXISTS(SELECT 1 FROM dbo.Fact_Zone_Traffic_Snapshot T WITH(UPDLOCK,HOLDLOCK) WHERE T.DateKey=S.DateKey AND T.TimeKey=S.TimeKey AND T.LocationKey=S.LocationKey AND T.ServiceTypeKey=S.ServiceTypeKey);
 UPDATE etl.AggregateWatermark SET LastTripKey=@YellowGreenMax,UpdatedAt=SYSDATETIME() WHERE AggregateName=''ZoneTraffic'' AND FactName=''YellowGreen'';
UPDATE etl.AggregateWatermark SET LastTripKey=@FHVMax,UpdatedAt=SYSDATETIME() WHERE AggregateName=''ZoneTraffic'' AND FactName=''FHV'';
UPDATE etl.AggregateWatermark SET LastTripKey=@HVFHVMax,UpdatedAt=SYSDATETIME() WHERE AggregateName=''ZoneTraffic'' AND FactName=''HVFHV'';
 COMMIT TRAN;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
';
EXEC sys.sp_executesql N'SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @FHVPrev bigint = (SELECT LastTripKey FROM etl.AggregateWatermark WITH (UPDLOCK,HOLDLOCK) WHERE AggregateName=''BasePerformance'' AND FactName=''FHV'');
 DECLARE @FHVMax bigint = ISNULL((SELECT MAX(TripKey) FROM dbo.Fact_FHV_Trips),0);
 IF @FHVPrev IS NULL OR @FHVMax < @FHVPrev THROW 55101, ''Missing watermark or transactional Fact keys reset; manual rebuild required.'',1;
 DECLARE @HVFHVPrev bigint = (SELECT LastTripKey FROM etl.AggregateWatermark WITH (UPDLOCK,HOLDLOCK) WHERE AggregateName=''BasePerformance'' AND FactName=''HVFHV'');
 DECLARE @HVFHVMax bigint = ISNULL((SELECT MAX(TripKey) FROM dbo.Fact_HVFHV_Trips),0);
 IF @HVFHVPrev IS NULL OR @HVFHVMax < @HVFHVPrev THROW 55101, ''Missing watermark or transactional Fact keys reset; manual rebuild required.'',1;
;WITH BaseRows AS
    (
        SELECT PickupDateKey AS DateKey, DispatchBaseKey, ServiceTypeKey,
               CONVERT(INT, 0) AS HVFHSProviderKey,
               CONVERT(BIGINT, TripCount) AS Trips,
               TripDurationSeconds AS DurationSeconds,
               CAST(NULL AS BIGINT) AS WaitingSeconds,
               CAST(NULL AS BIGINT) AS SharedRequests,
               CAST(NULL AS BIGINT) AS SharedMatches,
               CAST(NULL AS BIGINT) AS WAVRequests,
               CAST(NULL AS BIGINT) AS WAVMatches,
               CAST(NULL AS DECIMAL(28,2)) AS DriverPay
        FROM dbo.Fact_FHV_Trips WHERE TripKey>@FHVPrev AND TripKey<=@FHVMax
        UNION ALL
        SELECT F.PickupDateKey, F.DispatchBaseKey, F.ServiceTypeKey,
               F.HVFHSProviderKey, CONVERT(BIGINT, F.TripCount),
               F.TripDurationSeconds, F.WaitingTimeSeconds,
               CONVERT(BIGINT, CASE WHEN FL.IsSharedRequest = ''Y'' THEN 1 ELSE 0 END),
               CONVERT(BIGINT, CASE WHEN FL.IsSharedMatch = ''Y'' THEN 1 ELSE 0 END),
               CONVERT(BIGINT, CASE WHEN FL.IsWAVRequest = ''Y'' THEN 1 ELSE 0 END),
               CONVERT(BIGINT, CASE WHEN FL.IsWAVMatch = ''Y'' THEN 1 ELSE 0 END),
               CONVERT(DECIMAL(28,2), F.DriverPayAmount)
        FROM dbo.Fact_HVFHV_Trips F
        LEFT JOIN dbo.Dim_HVFHVFlags FL
            ON FL.HVFHVFlagKey = F.HVFHVFlagKey
        WHERE F.TripKey>@HVFHVPrev AND F.TripKey<=@HVFHVMax
    )

 SELECT DateKey,DispatchBaseKey,ServiceTypeKey,HVFHSProviderKey,
        SUM(Trips) AS TotalTrips,
        SUM(DurationSeconds) AS TotalTripDurationSeconds,
        COUNT_BIG(DurationSeconds) AS DurationTripCount,
        CONVERT(decimal(18,2),SUM(CONVERT(decimal(28,2),DurationSeconds))/NULLIF(COUNT_BIG(DurationSeconds),0)) AS AverageTripDurationSeconds,
        SUM(WaitingSeconds) AS TotalWaitingTimeSeconds,
        COUNT_BIG(WaitingSeconds) AS WaitingTripCount,
        CONVERT(decimal(18,2),SUM(CONVERT(decimal(28,2),WaitingSeconds))/NULLIF(COUNT_BIG(WaitingSeconds),0)) AS AverageWaitingTimeSeconds,
        SUM(SharedRequests) AS TotalSharedRequests,
        SUM(SharedMatches) AS TotalSharedMatches,
        SUM(WAVRequests) AS TotalWAVRequests,
        SUM(WAVMatches) AS TotalWAVMatches,
        SUM(DriverPay) AS TotalDriverPay
 INTO #Delta FROM BaseRows GROUP BY DateKey,DispatchBaseKey,ServiceTypeKey,HVFHSProviderKey;

 UPDATE T SET
    T.TotalTrips=T.TotalTrips+S.TotalTrips,
    T.TotalTripDurationSeconds=CASE WHEN T.TotalTripDurationSeconds IS NULL AND S.TotalTripDurationSeconds IS NULL THEN NULL ELSE COALESCE(T.TotalTripDurationSeconds,0)+COALESCE(S.TotalTripDurationSeconds,0) END,
    T.DurationTripCount=T.DurationTripCount+S.DurationTripCount,
    T.TotalWaitingTimeSeconds=CASE WHEN T.TotalWaitingTimeSeconds IS NULL AND S.TotalWaitingTimeSeconds IS NULL THEN NULL ELSE COALESCE(T.TotalWaitingTimeSeconds,0)+COALESCE(S.TotalWaitingTimeSeconds,0) END,
    T.WaitingTripCount=T.WaitingTripCount+S.WaitingTripCount,
    T.TotalSharedRequests=CASE WHEN T.TotalSharedRequests IS NULL AND S.TotalSharedRequests IS NULL THEN NULL ELSE COALESCE(T.TotalSharedRequests,0)+COALESCE(S.TotalSharedRequests,0) END,
    T.TotalSharedMatches=CASE WHEN T.TotalSharedMatches IS NULL AND S.TotalSharedMatches IS NULL THEN NULL ELSE COALESCE(T.TotalSharedMatches,0)+COALESCE(S.TotalSharedMatches,0) END,
    T.TotalWAVRequests=CASE WHEN T.TotalWAVRequests IS NULL AND S.TotalWAVRequests IS NULL THEN NULL ELSE COALESCE(T.TotalWAVRequests,0)+COALESCE(S.TotalWAVRequests,0) END,
    T.TotalWAVMatches=CASE WHEN T.TotalWAVMatches IS NULL AND S.TotalWAVMatches IS NULL THEN NULL ELSE COALESCE(T.TotalWAVMatches,0)+COALESCE(S.TotalWAVMatches,0) END,
    T.TotalDriverPay=CASE WHEN T.TotalDriverPay IS NULL AND S.TotalDriverPay IS NULL THEN NULL ELSE COALESCE(T.TotalDriverPay,0)+COALESCE(S.TotalDriverPay,0) END,
    T.AverageTripDurationSeconds=CONVERT(decimal(18,2),(CONVERT(decimal(28,2),COALESCE(T.TotalTripDurationSeconds,0))+COALESCE(S.TotalTripDurationSeconds,0))/NULLIF(T.DurationTripCount+S.DurationTripCount,0)),
    T.AverageWaitingTimeSeconds=CONVERT(decimal(18,2),(CONVERT(decimal(28,2),COALESCE(T.TotalWaitingTimeSeconds,0))+COALESCE(S.TotalWaitingTimeSeconds,0))/NULLIF(T.WaitingTripCount+S.WaitingTripCount,0)),
    T.SnapshotUpdatedAt=SYSDATETIME()
 FROM dbo.Fact_Base_Performance_Snapshot T JOIN #Delta S ON T.DateKey=S.DateKey AND T.DispatchBaseKey=S.DispatchBaseKey AND T.ServiceTypeKey=S.ServiceTypeKey AND T.HVFHSProviderKey=S.HVFHSProviderKey;
 INSERT dbo.Fact_Base_Performance_Snapshot(DateKey, DispatchBaseKey, ServiceTypeKey, HVFHSProviderKey, TotalTrips, TotalTripDurationSeconds, DurationTripCount, AverageTripDurationSeconds, TotalWaitingTimeSeconds, WaitingTripCount, AverageWaitingTimeSeconds, TotalSharedRequests, TotalSharedMatches, TotalWAVRequests, TotalWAVMatches, TotalDriverPay)
 SELECT S.DateKey, S.DispatchBaseKey, S.ServiceTypeKey, S.HVFHSProviderKey, S.TotalTrips, S.TotalTripDurationSeconds, S.DurationTripCount, S.AverageTripDurationSeconds, S.TotalWaitingTimeSeconds, S.WaitingTripCount, S.AverageWaitingTimeSeconds, S.TotalSharedRequests, S.TotalSharedMatches, S.TotalWAVRequests, S.TotalWAVMatches, S.TotalDriverPay
 FROM #Delta S WHERE NOT EXISTS(SELECT 1 FROM dbo.Fact_Base_Performance_Snapshot T WITH(UPDLOCK,HOLDLOCK) WHERE T.DateKey=S.DateKey AND T.DispatchBaseKey=S.DispatchBaseKey AND T.ServiceTypeKey=S.ServiceTypeKey AND T.HVFHSProviderKey=S.HVFHSProviderKey);
 UPDATE etl.AggregateWatermark SET LastTripKey=@FHVMax,UpdatedAt=SYSDATETIME() WHERE AggregateName=''BasePerformance'' AND FactName=''FHV'';
UPDATE etl.AggregateWatermark SET LastTripKey=@HVFHVMax,UpdatedAt=SYSDATETIME() WHERE AggregateName=''BasePerformance'' AND FactName=''HVFHV'';
 COMMIT TRAN;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
';
EXEC sys.sp_executesql N'SET NOCOUNT ON;
-- Financial excludes ordinary FHV by design.
DECLARE @FinancialSource BIGINT =
    (SELECT COALESCE(SUM(CONVERT(BIGINT,TripCount)),0)
     FROM dbo.Fact_YellowGreen_Trips) +
    (SELECT COALESCE(SUM(CONVERT(BIGINT,TripCount)),0)
     FROM dbo.Fact_HVFHV_Trips);
DECLARE @AllSource BIGINT = @FinancialSource +
    (SELECT COALESCE(SUM(CONVERT(BIGINT,TripCount)),0)
     FROM dbo.Fact_FHV_Trips);
IF @FinancialSource <> (SELECT COALESCE(SUM(TotalTrips),0) FROM dbo.Fact_Daily_Financial_Snapshot)
    THROW 54101, ''Financial trip totals do not match'', 1;
IF @AllSource <> (SELECT COALESCE(SUM(TotalPickups),0) FROM dbo.Fact_Zone_Traffic_Snapshot)
    THROW 54102, ''Zone pickup totals do not match'', 1;
IF @AllSource <> (SELECT COALESCE(SUM(TotalDropoffs),0) FROM dbo.Fact_Zone_Traffic_Snapshot)
    THROW 54103, ''Zone dropoff totals do not match'', 1;
DECLARE @BaseSource BIGINT =
    (SELECT COALESCE(SUM(CONVERT(BIGINT,TripCount)),0) FROM dbo.Fact_FHV_Trips) +
    (SELECT COALESCE(SUM(CONVERT(BIGINT,TripCount)),0) FROM dbo.Fact_HVFHV_Trips);
IF @BaseSource <> (SELECT COALESCE(SUM(TotalTrips),0) FROM dbo.Fact_Base_Performance_Snapshot)
    THROW 54104, ''Base performance trip totals do not match'', 1;

IF EXISTS(SELECT 1 FROM etl.AggregateWatermark W
WHERE (W.FactName=''YellowGreen'' AND W.LastTripKey < (SELECT ISNULL(MAX(TripKey),0) FROM dbo.Fact_YellowGreen_Trips))
   OR (W.FactName=''FHV'' AND W.LastTripKey < (SELECT ISNULL(MAX(TripKey),0) FROM dbo.Fact_FHV_Trips))
   OR (W.FactName=''HVFHV'' AND W.LastTripKey < (SELECT ISNULL(MAX(TripKey),0) FROM dbo.Fact_HVFHV_Trips)))
 THROW 55112,''Aggregate watermarks lag transactional facts.'',1;
';
COMMIT TRANSACTION; END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
SET NOCOUNT ON;
IF DB_NAME() <> 'NYCTaxi_Staging'
    THROW 51000, 'Chon connection NYCTaxi_Staging.', 1;
IF OBJECT_ID('stg.YellowTrip') IS NULL OR OBJECT_ID('stg.GreenTrip') IS NULL
    OR OBJECT_ID('stg.FHVTrip') IS NULL OR OBJECT_ID('stg.FHVHVTrip') IS NULL
    OR OBJECT_ID('stg.TaxiZone') IS NULL
    THROW 51001, 'Chay PKG_01 de tao va nap staging truoc.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'clean')
    EXEC('CREATE SCHEMA clean AUTHORIZATION dbo');

/* ----------------------- 1. BANG CLEAN ----------------------- */

IF OBJECT_ID('clean.TaxiZone', 'U') IS NULL
BEGIN
    CREATE TABLE clean.TaxiZone
    (
        LocationID   INT           NOT NULL,
        Borough      NVARCHAR(100) NULL,
        Zone         NVARCHAR(200) NULL,
        ServiceZone  NVARCHAR(100) NULL,
        CONSTRAINT PK_CleanTaxiZone PRIMARY KEY (LocationID)
    );
END;

IF OBJECT_ID('clean.Trip', 'U') IS NULL
BEGIN
    CREATE TABLE clean.Trip
    (
        TripCleanID             BIGINT IDENTITY(1,1) NOT NULL,
        TaxiType                VARCHAR(10) NOT NULL,

        VendorID                INT NULL,
        HVFHSLicenseNum         VARCHAR(30) NULL,
        DispatchingBaseNum      VARCHAR(30) NULL,
        OriginatingBaseNum      VARCHAR(30) NULL,
        AffiliatedBaseNum       VARCHAR(30) NULL,

        RequestDateTime         DATETIME2(0) NULL,
        OnSceneDateTime         DATETIME2(0) NULL,
        PickupDateTime          DATETIME2(0) NULL,
        DropoffDateTime         DATETIME2(0) NULL,
        TripDurationSeconds     BIGINT NULL,

        PULocationID            INT NULL,
        DOLocationID            INT NULL,
        PassengerCount          INT NULL,
        TripDistanceMiles       DECIMAL(12,3) NULL,

        RateCodeID              INT NULL,
        PaymentTypeID           INT NULL,
        TripTypeID              INT NULL,
        StoreAndFwdFlag         VARCHAR(5) NULL,

        FareAmount              DECIMAL(18,2) NULL,
        ExtraAmount             DECIMAL(18,2) NULL,
        MTATaxAmount            DECIMAL(18,2) NULL,
        TipAmount               DECIMAL(18,2) NULL,
        TollsAmount             DECIMAL(18,2) NULL,
        ImprovementSurcharge    DECIMAL(18,2) NULL,
        CongestionSurcharge     DECIMAL(18,2) NULL,
        AirportFee              DECIMAL(18,2) NULL,
        CBDCongestionFee        DECIMAL(18,2) NULL,
        BCFAmount               DECIMAL(18,2) NULL,
        SalesTaxAmount          DECIMAL(18,2) NULL,
        DriverPayAmount         DECIMAL(18,2) NULL,
        TotalAmount             DECIMAL(18,2) NULL,
        IsTotalCalculated       BIT NOT NULL,

        SharedRequestFlag       VARCHAR(5) NULL,
        SharedMatchFlag         VARCHAR(5) NULL,
        AccessARideFlag         VARCHAR(5) NULL,
        WAVRequestFlag          VARCHAR(5) NULL,
        WAVMatchFlag            VARCHAR(5) NULL,

        IsCoreValid             BIT NOT NULL,
        QualityIssue            VARCHAR(2000) NULL,
        CleanedAt               DATETIME2(0) NOT NULL
            CONSTRAINT DF_CleanTrip_CleanedAt DEFAULT SYSDATETIME(),

        CONSTRAINT PK_CleanTrip PRIMARY KEY CLUSTERED (TripCleanID),
        CONSTRAINT CK_CleanTrip_TaxiType
            CHECK (TaxiType IN ('YELLOW', 'GREEN', 'FHV', 'FHVHV'))
    );

    CREATE INDEX IX_CleanTrip_PickupDateTime
        ON clean.Trip (PickupDateTime, TaxiType);

    CREATE INDEX IX_CleanTrip_Location
        ON clean.Trip (PULocationID, DOLocationID);
END;

IF COL_LENGTH('clean.Trip', 'ETLSourceKey') IS NULL
    ALTER TABLE clean.Trip ADD [ETLSourceKey] NVARCHAR(260) NULL;
IF COL_LENGTH('clean.Trip', 'ETLFileHash') IS NULL
    ALTER TABLE clean.Trip ADD [ETLFileHash] CHAR(64) NULL;
IF COL_LENGTH('clean.Trip', 'ETLLoadedAt') IS NULL
    ALTER TABLE clean.Trip ADD [ETLLoadedAt] DATETIME2(0) NULL;
IF COL_LENGTH('clean.Trip', 'TripDistanceKm') IS NULL
    ALTER TABLE clean.Trip ADD [TripDistanceKm] DECIMAL(14,3) NULL;
IF COL_LENGTH('clean.Trip', 'AverageSpeedKmh') IS NULL
    ALTER TABLE clean.Trip ADD [AverageSpeedKmh] DECIMAL(14,3) NULL;
IF COL_LENGTH('clean.Trip', 'SourceTripDurationSeconds') IS NULL
    ALTER TABLE clean.Trip ADD [SourceTripDurationSeconds] BIGINT NULL;
IF COL_LENGTH('clean.Trip', 'RequestWaitSeconds') IS NULL
    ALTER TABLE clean.Trip ADD [RequestWaitSeconds] BIGINT NULL;
IF COL_LENGTH('clean.Trip', 'SourceSRFlag') IS NULL
    ALTER TABLE clean.Trip ADD [SourceSRFlag] VARCHAR(5) NULL;
IF COL_LENGTH('clean.Trip', 'EHailFeeAmount') IS NULL
    ALTER TABLE clean.Trip ADD [EHailFeeAmount] DECIMAL(18,2) NULL;
IF COL_LENGTH('clean.Trip', 'QualityIssue') < 2000
    ALTER TABLE clean.Trip ALTER COLUMN QualityIssue VARCHAR(2000) NULL;

/* Hai view nay duoc dung o buoc Load. */
EXEC('CREATE OR ALTER VIEW clean.ValidTrip AS
      SELECT * FROM clean.Trip WHERE IsCoreValid = 1;');
EXEC('CREATE OR ALTER VIEW clean.RejectedTrip AS
      SELECT * FROM clean.Trip WHERE IsCoreValid = 0;');
EXEC('CREATE OR ALTER VIEW clean.WarningTrip AS
      SELECT * FROM clean.Trip WHERE IsCoreValid = 1 AND QualityIssue IS NOT NULL;');
EXEC('CREATE OR ALTER VIEW clean.RevenueTrip AS
      SELECT * FROM clean.Trip WHERE IsCoreValid = 1 AND TotalAmount IS NOT NULL;');
EXEC('CREATE OR ALTER VIEW clean.TransformSummary AS
      SELECT TaxiType, COUNT_BIG(*) AS TotalRows,
          COUNT_BIG(CASE WHEN IsCoreValid=1 THEN 1 END) AS ValidRows,
          COUNT_BIG(CASE WHEN IsCoreValid=0 THEN 1 END) AS RejectedRows,
          COUNT_BIG(CASE WHEN IsCoreValid=1 AND QualityIssue IS NOT NULL THEN 1 END) AS WarningRows,
          COUNT_BIG(CASE WHEN IsCoreValid=1 AND TotalAmount IS NOT NULL THEN 1 END) AS RevenueAvailableRows
      FROM clean.Trip GROUP BY TaxiType;');


/* PKG_01 moi luu lineage cho tung tep. */
IF OBJECT_ID('etl.ExtractFileLog', 'U') IS NULL
    THROW 51200, 'Can etl.ExtractFileLog tu PKG_01 moi.', 1;
IF COL_LENGTH('stg.YellowTrip','ETLSourceKey') IS NULL
    OR COL_LENGTH('stg.GreenTrip','ETLSourceKey') IS NULL
    OR COL_LENGTH('stg.FHVTrip','ETLSourceKey') IS NULL
    OR COL_LENGTH('stg.FHVHVTrip','ETLSourceKey') IS NULL
    OR COL_LENGTH('stg.TaxiZone','ETLSourceKey') IS NULL
    THROW 51201, 'Staging thieu ETLSourceKey. Dung PKG_01 moi de nap staging.', 1;

/* Dung lai dung cau truc log da tao o ban Transform truoc. */
IF OBJECT_ID('etl.TransformFileLog', 'U') IS NULL
    CREATE TABLE etl.TransformFileLog
    (
        DatasetCode VARCHAR(20) NOT NULL,
        SourceKey NVARCHAR(260) NOT NULL,
        FileHash CHAR(64) NOT NULL,
        RuleVersion VARCHAR(64) NOT NULL,
        ZoneHash CHAR(64) NOT NULL,
        SourceRows BIGINT NOT NULL,
        CleanRows BIGINT NOT NULL,
        ValidRows BIGINT NOT NULL,
        RejectedRows BIGINT NOT NULL,
        WarningRows BIGINT NOT NULL,
        CompletedAt DATETIME2(0) NOT NULL,
        CONSTRAINT PK_TransformFileLog PRIMARY KEY(DatasetCode,SourceKey),
        CONSTRAINT CK_TransformFileLog_Counts CHECK
            (SourceRows=CleanRows AND CleanRows=ValidRows+RejectedRows)
    );

IF COL_LENGTH('etl.TransformFileLog','RuleVersion') IS NULL
    OR COL_LENGTH('etl.TransformFileLog','ZoneHash') IS NULL
    OR COL_LENGTH('etl.TransformFileLog','SourceRows') IS NULL
    OR COL_LENGTH('etl.TransformFileLog','CleanRows') IS NULL
    THROW 51202, 'Cau truc etl.TransformFileLog cu khong tuong thich.', 1;

/* Dem/tra cuu theo tep bang index gon, tranh doc cac cot do luong cu. */
IF NOT EXISTS(SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID('clean.Trip') AND name='IX_CleanTrip_Source')
    EXEC('CREATE INDEX IX_CleanTrip_Source ON clean.Trip(TaxiType,ETLSourceKey)
          INCLUDE(ETLFileHash);');

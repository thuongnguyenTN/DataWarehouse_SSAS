SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_ID(N'NYCTaxi_Staging') IS NULL OR DB_ID(N'NYCTaxi_DWH') IS NULL
    THROW 55001, 'Missing database NYCTaxi_Staging or NYCTaxi_DWH.', 1;
IF OBJECT_ID(N'NYCTaxi_Staging.clean.ValidTrip',N'V') IS NULL
    THROW 55002, 'Missing NYCTaxi_Staging.clean.ValidTrip; run Transform first.', 1;
IF OBJECT_ID(N'NYCTaxi_Staging.clean.TaxiZone',N'U') IS NULL
    THROW 55003, 'Missing clean.TaxiZone.', 1;
IF OBJECT_ID(N'dbo.Fact_YellowGreen_Trips',N'U') IS NULL
 OR OBJECT_ID(N'dbo.Fact_FHV_Trips',N'U') IS NULL
 OR OBJECT_ID(N'dbo.Fact_HVFHV_Trips',N'U') IS NULL
    THROW 55004, 'Missing transactional Fact tables; run 04_create_nyctaxi_dwh.sql.', 1;
IF NOT EXISTS(SELECT 1 FROM dbo.Dim_Time WHERE MinuteOfDay=0 AND TimeKey=1)
 OR NOT EXISTS(SELECT 1 FROM dbo.Dim_Time WHERE MinuteOfDay=1439 AND TimeKey=1440)
    THROW 55005, 'Dim_Time not initialized (TimeKey must be MinuteOfDay + 1).',1;
IF NOT EXISTS(SELECT 1 FROM NYCTaxi_Staging.clean.ValidTrip)
    THROW 55006, 'No valid trips in clean.ValidTrip.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'etl')
    EXEC(N'CREATE SCHEMA etl AUTHORIZATION dbo');
IF OBJECT_ID(N'etl.LoadStepLog',N'U') IS NULL
    CREATE TABLE etl.LoadStepLog
    (
        LogID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        StepName NVARCHAR(100) NOT NULL,
        InsertedRows BIGINT NULL,
        CompletedAt DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
    );
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Fact_YellowGreen_Trips') AND name=N'UX_FYG_RecordHash')
    CREATE UNIQUE INDEX UX_FYG_RecordHash ON dbo.Fact_YellowGreen_Trips(RecordHash) WHERE RecordHash IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Fact_FHV_Trips') AND name=N'UX_FHV_RecordHash')
    CREATE UNIQUE INDEX UX_FHV_RecordHash ON dbo.Fact_FHV_Trips(RecordHash) WHERE RecordHash IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Fact_HVFHV_Trips') AND name=N'UX_HVFHV_RecordHash')
    CREATE UNIQUE INDEX UX_HVFHV_RecordHash ON dbo.Fact_HVFHV_Trips(RecordHash) WHERE RecordHash IS NOT NULL;

IF OBJECT_ID('etl.FactChangeAudit','U') IS NULL CREATE TABLE etl.FactChangeAudit(
 AuditId bigint IDENTITY PRIMARY KEY,TableName sysname NOT NULL,RowJson nvarchar(max) NOT NULL,
 DeletedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
IF COL_LENGTH('dbo.Fact_YellowGreen_Trips','SourceDataset') IS NULL ALTER TABLE dbo.Fact_YellowGreen_Trips ADD SourceDataset varchar(20) NULL;
IF COL_LENGTH('dbo.Fact_YellowGreen_Trips','SourceKey') IS NULL ALTER TABLE dbo.Fact_YellowGreen_Trips ADD SourceKey nvarchar(260) NULL;
IF COL_LENGTH('dbo.Fact_FHV_Trips','SourceDataset') IS NULL ALTER TABLE dbo.Fact_FHV_Trips ADD SourceDataset varchar(20) NULL;
IF COL_LENGTH('dbo.Fact_FHV_Trips','SourceKey') IS NULL ALTER TABLE dbo.Fact_FHV_Trips ADD SourceKey nvarchar(260) NULL;
IF COL_LENGTH('dbo.Fact_HVFHV_Trips','SourceDataset') IS NULL ALTER TABLE dbo.Fact_HVFHV_Trips ADD SourceDataset varchar(20) NULL;
IF COL_LENGTH('dbo.Fact_HVFHV_Trips','SourceKey') IS NULL ALTER TABLE dbo.Fact_HVFHV_Trips ADD SourceKey nvarchar(260) NULL;

-- FILE_V1_20261031
SET NOCOUNT ON;
IF OBJECT_ID('etl.DwhFileLog','U') IS NULL
CREATE TABLE etl.DwhFileLog(
 DatasetCode varchar(20) NOT NULL, SourceKey nvarchar(260) NOT NULL,
 SourceVersion char(64) NULL, LoaderVersion varchar(40) NULL,
 Status varchar(20) NOT NULL, ForceReload bit NOT NULL DEFAULT 0,
 ValidRows bigint NULL, FactRows bigint NULL, InsertedRows bigint NULL,
 UpdatedRows bigint NULL, DeletedRows bigint NULL,
 UnknownMask int NOT NULL DEFAULT 0,
 LocationMapHash char(64) NULL, BaseMapHash char(64) NULL, OtherMapHash char(64) NULL,
 CompletedAt datetime2 NULL, ErrorMessage nvarchar(max) NULL,
 CONSTRAINT PK_DwhFileLog PRIMARY KEY(DatasetCode,SourceKey));
EXEC(N'CREATE OR ALTER VIEW etl.DwhSourceState AS
 SELECT T.DatasetCode,T.SourceKey,T.FileHash,T.ValidRows,T.SourceRows,T.CompletedAt,
 CONVERT(char(64),HASHBYTES(''SHA2_256'',CONCAT(T.FileHash,''|'',T.RuleVersion,''|'',T.ZoneHash,
 ''|'',T.SourceRows,''|'',T.ValidRows,''|'',T.RejectedRows,''|'',CONVERT(varchar(33),T.CompletedAt,126))),2) AS SourceVersion
 FROM NYCTaxi_Staging.etl.TransformFileLog T
 JOIN NYCTaxi_Staging.etl.ExtractFileLog E ON E.DatasetCode=T.DatasetCode AND E.SourceKey=T.SourceKey
 WHERE E.DatasetCode IN(''yellow'',''green'',''fhv'',''fhvhv'') AND E.LoadStatus=''SUCCEEDED'' AND E.RowsLoaded=E.ExpectedRows
 AND E.FileHash=T.FileHash AND E.ExpectedRows=T.SourceRows AND T.CleanRows=T.SourceRows
 AND T.ValidRows+T.RejectedRows=T.CleanRows;');

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_YellowGreen_Trips') AND name='IX_DwhFile_Source') CREATE INDEX IX_DwhFile_Source ON dbo.Fact_YellowGreen_Trips(SourceDataset,SourceKey) INCLUDE(RecordHash);
IF EXISTS(SELECT 1 FROM dbo.Fact_YellowGreen_Trips WHERE SourceKey IS NULL OR SourceDataset IS NULL) THROW 55946,'Legacy facts have no source. Migrate lineage before incremental loading.',1;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_FHV_Trips') AND name='IX_DwhFile_Source') CREATE INDEX IX_DwhFile_Source ON dbo.Fact_FHV_Trips(SourceDataset,SourceKey) INCLUDE(RecordHash);
IF EXISTS(SELECT 1 FROM dbo.Fact_FHV_Trips WHERE SourceKey IS NULL OR SourceDataset IS NULL) THROW 55946,'Legacy facts have no source. Migrate lineage before incremental loading.',1;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_HVFHV_Trips') AND name='IX_DwhFile_Source') CREATE INDEX IX_DwhFile_Source ON dbo.Fact_HVFHV_Trips(SourceDataset,SourceKey) INCLUDE(RecordHash);
IF EXISTS(SELECT 1 FROM dbo.Fact_HVFHV_Trips WHERE SourceKey IS NULL OR SourceDataset IS NULL) THROW 55946,'Legacy facts have no source. Migrate lineage before incremental loading.',1;

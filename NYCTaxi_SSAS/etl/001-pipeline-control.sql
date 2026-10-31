SET NOCOUNT ON;
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
IF OBJECT_ID('etl.PipelineRun','U') IS NULL
CREATE TABLE etl.PipelineRun(
 RunId uniqueidentifier NOT NULL PRIMARY KEY, ConfigHash char(64) NOT NULL,
 StartMonth char(7) NOT NULL, EndMonth char(7) NOT NULL, RowLimit int NOT NULL,
 Status varchar(20) NOT NULL CHECK(Status IN ('RUNNING','SUCCEEDED','FAILED')),
 StartedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), CompletedAt datetime2 NULL,
 HostName nvarchar(128) NOT NULL DEFAULT HOST_NAME(), ErrorMessage nvarchar(max) NULL);
IF OBJECT_ID('etl.PipelineStep','U') IS NULL
CREATE TABLE etl.PipelineStep(
 StepId bigint IDENTITY PRIMARY KEY, RunId uniqueidentifier NOT NULL REFERENCES etl.PipelineRun(RunId),
 Stage varchar(30) NOT NULL, TaskName nvarchar(260) NOT NULL, Status varchar(20) NOT NULL,
 StartedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(), CompletedAt datetime2 NULL,
 ErrorNumber int NULL, ErrorMessage nvarchar(max) NULL, Detail nvarchar(max) NULL);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('etl.PipelineStep') AND name='IX_PipelineStep_Run')
 CREATE INDEX IX_PipelineStep_Run ON etl.PipelineStep(RunId,StepId);
IF OBJECT_ID('etl.PackageError','U') IS NULL
CREATE TABLE etl.PackageError(
 ErrorId bigint IDENTITY PRIMARY KEY, ExecutionId nvarchar(64) NULL,
 PackageName nvarchar(260) NULL, SourceName nvarchar(260) NULL,
 ErrorCode int NULL, ErrorDescription nvarchar(max) NULL,
 CapturedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME());

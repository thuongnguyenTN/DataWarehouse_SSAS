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
 WHERE E.DatasetCode IN(''yellow'',''green'',''fhv'',''fhvhv'')
 AND E.LoadStatus=''SUCCEEDED'' AND E.RowsLoaded=E.ExpectedRows
 AND E.FileHash=T.FileHash AND E.ExpectedRows=T.SourceRows AND T.CleanRows=T.SourceRows
 AND T.ValidRows+T.RejectedRows=T.CleanRows;');

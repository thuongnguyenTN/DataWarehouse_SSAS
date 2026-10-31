SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM NYCTaxi_Staging.etl.ExtractFileLog E
 LEFT JOIN etl.DwhSourceState S ON S.DatasetCode=E.DatasetCode AND S.SourceKey=E.SourceKey
 WHERE E.DatasetCode IN('yellow','green','fhv','fhvhv') AND E.LoadStatus='SUCCEEDED' AND S.SourceKey IS NULL)
 THROW 55944,'Extract/Transform coverage is incomplete; DWH checkpoint cannot be accepted.',1;

DECLARE @LocationMapHash char(64),@BaseMapHash char(64),@OtherMapHash char(64),@MapText nvarchar(max);
SET @MapText=(SELECT LocationKey,LocationID FROM dbo.Dim_Location ORDER BY LocationKey FOR JSON PATH);
SET @LocationMapHash=CONVERT(char(64),HASHBYTES('SHA2_256',@MapText),2);
SET @MapText=(SELECT BaseKey,BaseNumber FROM dbo.Dim_Base ORDER BY BaseKey FOR JSON PATH);
SET @BaseMapHash=CONVERT(char(64),HASHBYTES('SHA2_256',@MapText),2);
SET @MapText=CONCAT(
 (SELECT ServiceTypeKey,ServiceCode FROM dbo.Dim_ServiceType ORDER BY ServiceTypeKey FOR JSON PATH),
 (SELECT VendorKey,VendorID FROM dbo.Dim_Vendor ORDER BY VendorKey FOR JSON PATH),
 (SELECT RateCodeKey,RateCodeID FROM dbo.Dim_RateCode ORDER BY RateCodeKey FOR JSON PATH),
 (SELECT PaymentTypeKey,PaymentTypeID FROM dbo.Dim_PaymentType ORDER BY PaymentTypeKey FOR JSON PATH),
 (SELECT TripTypeKey,TripTypeID FROM dbo.Dim_TripType ORDER BY TripTypeKey FOR JSON PATH),
 (SELECT HVFHSProviderKey,LicenseNumber FROM dbo.Dim_HVFHSProvider ORDER BY HVFHSProviderKey FOR JSON PATH));
SET @OtherMapHash=CONVERT(char(64),HASHBYTES('SHA2_256',@MapText),2);


DROP TABLE IF EXISTS #DwhTodo;
SELECT S.* INTO #DwhTodo FROM etl.DwhSourceState S
LEFT JOIN etl.DwhFileLog L ON L.DatasetCode=S.DatasetCode AND L.SourceKey=S.SourceKey
WHERE L.SourceKey IS NULL OR L.Status<>'SUCCEEDED' OR L.ForceReload=1
 OR L.SourceVersion<>S.SourceVersion OR L.LoaderVersion<>'FILE_V1_20261031'
 OR (L.UnknownMask&1=1 AND L.LocationMapHash<>@LocationMapHash)
 OR (L.UnknownMask&2=2 AND L.BaseMapHash<>@BaseMapHash)
 OR (L.UnknownMask&4=4 AND L.OtherMapHash<>@OtherMapHash);
CREATE UNIQUE CLUSTERED INDEX IX_DwhTodo ON #DwhTodo(DatasetCode,SourceKey);

IF EXISTS(SELECT 1 FROM #DwhTodo) THROW 55945,'DWH file checkpoints are incomplete.',1;
DROP TABLE #DwhTodo;
UPDATE dbo.Dim_LoadBatch SET BatchStatus='SUCCEEDED',LoadedAt=SYSDATETIME() WHERE BatchStatus='READY' AND BatchID LIKE 'CLEAN-%';
SELECT COUNT(*) AS CompletedFiles, SUM(FactRows) AS CheckpointFactRows FROM etl.DwhFileLog WHERE Status='SUCCEEDED';

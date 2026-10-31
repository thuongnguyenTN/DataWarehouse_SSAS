SET NOCOUNT ON; SET XACT_ABORT ON;

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

DELETE FROM #DwhTodo WHERE DatasetCode NOT IN ('fhvhv');
DECLARE @Dataset varchar(20),@Source nvarchar(260),@Expected bigint,@Token char(64),
 @Inserted bigint=0,@Updated bigint=0,@Deleted bigint=0,@FactRows bigint,@Unknown int,
 @Files int=0,@Input bigint=0,@Error nvarchar(max);
DECLARE FileCursor CURSOR LOCAL FAST_FORWARD FOR SELECT DatasetCode,SourceKey,ValidRows,SourceVersion FROM #DwhTodo ORDER BY DatasetCode,SourceKey;
OPEN FileCursor; FETCH NEXT FROM FileCursor INTO @Dataset,@Source,@Expected,@Token;
WHILE @@FETCH_STATUS=0
BEGIN
 BEGIN TRY
  BEGIN TRANSACTION;
  DROP TABLE IF EXISTS #CurrentFile; DROP TABLE IF EXISTS #Desired;
  SELECT * INTO #CurrentFile FROM #DwhTodo WHERE DatasetCode=@Dataset AND SourceKey=@Source;
  IF NOT EXISTS(SELECT 1 FROM etl.DwhSourceState WITH(HOLDLOCK) WHERE DatasetCode=@Dataset AND SourceKey=@Source AND SourceVersion=@Token)
   THROW 55940,'Source changed after DWH planning; retry after Transform.',1;
  IF EXISTS(SELECT 1 FROM NYCTaxi_Staging.clean.Trip C JOIN #CurrentFile P
    ON C.TaxiType=UPPER(P.DatasetCode) AND C.ETLSourceKey=P.SourceKey
    WHERE C.ETLFileHash IS NULL OR C.ETLFileHash<>P.FileHash)
   THROW 55947,'File clean lineage hash disagrees with Transform checkpoint.',1;
  IF (SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.Trip WHERE TaxiType=UPPER(@Dataset) AND ETLSourceKey=@Source)
   <>(SELECT SourceRows FROM #CurrentFile)
   THROW 55948,'File clean row coverage is incomplete.',1;
;WITH SourceRows AS
(
  SELECT C.*,
    HASHBYTES('SHA2_256',
      (SELECT C.TaxiType AS TaxiType,
            C.VendorID AS VendorID,
            C.HVFHSLicenseNum AS HVFHSLicenseNum,
            C.DispatchingBaseNum AS DispatchingBaseNum,
            C.OriginatingBaseNum AS OriginatingBaseNum,
            C.AffiliatedBaseNum AS AffiliatedBaseNum,
            C.RequestDateTime AS RequestDateTime,
            C.OnSceneDateTime AS OnSceneDateTime,
            C.PickupDateTime AS PickupDateTime,
            C.DropoffDateTime AS DropoffDateTime,
            C.TripDurationSeconds AS TripDurationSeconds,
            C.PULocationID AS PULocationID,
            C.DOLocationID AS DOLocationID,
            C.PassengerCount AS PassengerCount,
            C.TripDistanceMiles AS TripDistanceMiles,
            C.RateCodeID AS RateCodeID,
            C.PaymentTypeID AS PaymentTypeID,
            C.TripTypeID AS TripTypeID,
            C.StoreAndFwdFlag AS StoreAndFwdFlag,
            C.FareAmount AS FareAmount,
            C.ExtraAmount AS ExtraAmount,
            C.MTATaxAmount AS MTATaxAmount,
            C.TipAmount AS TipAmount,
            C.TollsAmount AS TollsAmount,
            C.ImprovementSurcharge AS ImprovementSurcharge,
            C.CongestionSurcharge AS CongestionSurcharge,
            C.AirportFee AS AirportFee,
            C.CBDCongestionFee AS CBDCongestionFee,
            C.BCFAmount AS BCFAmount,
            C.SalesTaxAmount AS SalesTaxAmount,
            C.DriverPayAmount AS DriverPayAmount,
            C.TotalAmount AS TotalAmount,
            C.IsTotalCalculated AS IsTotalCalculated,
            C.SharedRequestFlag AS SharedRequestFlag,
            C.SharedMatchFlag AS SharedMatchFlag,
            C.AccessARideFlag AS AccessARideFlag,
            C.WAVRequestFlag AS WAVRequestFlag,
            C.WAVMatchFlag AS WAVMatchFlag
       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    ) AS PayloadHash
  FROM NYCTaxi_Staging.clean.ValidTrip C
  INNER JOIN #CurrentFile F ON C.TaxiType=UPPER(F.DatasetCode) AND C.ETLSourceKey=F.SourceKey
  WHERE C.TaxiType='FHVHV'
),
Ranked AS
(
  SELECT S.*, ROW_NUMBER() OVER(PARTITION BY S.TaxiType,S.ETLSourceKey,S.PayloadHash ORDER BY S.TripCleanID) AS DuplicateOrdinal
  FROM SourceRows S
),
Tagged AS
(
  SELECT R.*,
    HASHBYTES('SHA2_256', CONCAT(R.TaxiType,'|',R.ETLSourceKey,'|',CONVERT(varchar(64),R.PayloadHash,2),':',R.DuplicateOrdinal)) AS RecordHash
  FROM Ranked R
),
C AS
(
    SELECT
        T.*,

        CASE
            WHEN UPPER(T.SharedRequestFlag) IN ('Y', 'N')
                THEN UPPER(T.SharedRequestFlag)
            ELSE 'U'
        END AS NormalizedSharedRequest,

        CASE
            WHEN UPPER(T.SharedMatchFlag) IN ('Y', 'N')
                THEN UPPER(T.SharedMatchFlag)
            ELSE 'U'
        END AS NormalizedSharedMatch,

        CASE
            WHEN UPPER(T.AccessARideFlag) IN ('Y', 'N')
                THEN UPPER(T.AccessARideFlag)
            ELSE 'U'
        END AS NormalizedAccessARide,

        CASE
            WHEN UPPER(T.WAVRequestFlag) IN ('Y', 'N')
                THEN UPPER(T.WAVRequestFlag)
            ELSE 'U'
        END AS NormalizedWAVRequest,

        CASE
            WHEN UPPER(T.WAVMatchFlag) IN ('Y', 'N')
                THEN UPPER(T.WAVMatchFlag)
            ELSE 'U'
        END AS NormalizedWAVMatch

    FROM Tagged AS T
    WHERE T.TaxiType = 'FHVHV'
),
FactValues AS (
SELECT
    COALESCE(RequestDate.DateKey, 0) AS RequestDateKey,
    COALESCE(OnSceneDate.DateKey, 0) AS OnSceneDateKey,
    COALESCE(PickupDate.DateKey, 0) AS PickupDateKey,
    COALESCE(DropoffDate.DateKey, 0) AS DropoffDateKey,

    COALESCE(RequestTime.TimeKey, 0) AS RequestTimeKey,
    COALESCE(OnSceneTime.TimeKey, 0) AS OnSceneTimeKey,
    COALESCE(PickupTime.TimeKey, 0) AS PickupTimeKey,
    COALESCE(DropoffTime.TimeKey, 0) AS DropoffTimeKey,

    COALESCE(PickupZone.LocationKey, 0)
        AS PickupLocationKey,

    COALESCE(DropoffZone.LocationKey, 0)
        AS DropoffLocationKey,

    COALESCE(ServiceType.ServiceTypeKey, 0)
        AS ServiceTypeKey,

    COALESCE(Provider.HVFHSProviderKey, 0)
        AS HVFHSProviderKey,

    COALESCE(DispatchBase.BaseKey, 0)
        AS DispatchBaseKey,

    COALESCE(OriginBase.BaseKey, 0)
        AS OriginBaseKey,

    COALESCE(Flags.HVFHVFlagKey, 0)
        AS HVFHVFlagKey,

    COALESCE(LoadBatch.LoadBatchKey,0) AS LoadBatchKey,
    1 AS TripCount,

    C.TripDistanceMiles,
    C.TripDurationSeconds,

    CASE
        WHEN C.RequestDateTime IS NOT NULL
         AND C.PickupDateTime >= C.RequestDateTime
        THEN DATEDIFF_BIG(
            SECOND,
            C.RequestDateTime,
            C.PickupDateTime
        )
    END AS WaitingTimeSeconds,

    CASE
        WHEN C.OnSceneDateTime IS NOT NULL
         AND C.PickupDateTime >= C.OnSceneDateTime
        THEN DATEDIFF_BIG(
            SECOND,
            C.OnSceneDateTime,
            C.PickupDateTime
        )
    END AS OnSceneToPickupSeconds,

    C.FareAmount AS BasePassengerFare,
    C.TollsAmount,
    C.BCFAmount,
    C.SalesTaxAmount,
    C.CongestionSurcharge,
    C.AirportFee,
    C.TipAmount,
    C.DriverPayAmount,
    C.CBDCongestionFee,
    C.TotalAmount AS GrossPassengerAmount,
    C.RecordHash AS RecordHash, LOWER(C.TaxiType) AS SourceDataset, C.ETLSourceKey AS SourceKey,
    CASE WHEN (C.PULocationID IS NOT NULL AND COALESCE(PickupZone.LocationKey,0)=0) OR (C.DOLocationID IS NOT NULL AND COALESCE(DropoffZone.LocationKey,0)=0) THEN 1 ELSE 0 END + CASE WHEN (C.DispatchingBaseNum IS NOT NULL AND COALESCE(DispatchBase.BaseKey,0)=0) OR (C.OriginatingBaseNum IS NOT NULL AND COALESCE(OriginBase.BaseKey,0)=0) THEN 2 ELSE 0 END + CASE WHEN (C.HVFHSLicenseNum IS NOT NULL AND COALESCE(Provider.HVFHSProviderKey,0)=0) THEN 4 ELSE 0 END AS UnresolvedMask

FROM C

LEFT JOIN dbo.Dim_Date AS RequestDate
    ON RequestDate.FullDate =
       CONVERT(DATE, C.RequestDateTime)

LEFT JOIN dbo.Dim_Date AS OnSceneDate
    ON OnSceneDate.FullDate =
       CONVERT(DATE, C.OnSceneDateTime)

LEFT JOIN dbo.Dim_Date AS PickupDate
    ON PickupDate.FullDate =
       CONVERT(DATE, C.PickupDateTime)

LEFT JOIN dbo.Dim_Date AS DropoffDate
    ON DropoffDate.FullDate =
       CONVERT(DATE, C.DropoffDateTime)

LEFT JOIN dbo.Dim_Time AS RequestTime
    ON RequestTime.MinuteOfDay =
       DATEPART(HOUR, C.RequestDateTime) * 60
       + DATEPART(MINUTE, C.RequestDateTime)

LEFT JOIN dbo.Dim_Time AS OnSceneTime
    ON OnSceneTime.MinuteOfDay =
       DATEPART(HOUR, C.OnSceneDateTime) * 60
       + DATEPART(MINUTE, C.OnSceneDateTime)

LEFT JOIN dbo.Dim_Time AS PickupTime
    ON PickupTime.MinuteOfDay =
       DATEPART(HOUR, C.PickupDateTime) * 60
       + DATEPART(MINUTE, C.PickupDateTime)

LEFT JOIN dbo.Dim_Time AS DropoffTime
    ON DropoffTime.MinuteOfDay =
       DATEPART(HOUR, C.DropoffDateTime) * 60
       + DATEPART(MINUTE, C.DropoffDateTime)

LEFT JOIN dbo.Dim_Location AS PickupZone
    ON PickupZone.LocationID = C.PULocationID

LEFT JOIN dbo.Dim_Location AS DropoffZone
    ON DropoffZone.LocationID = C.DOLocationID

LEFT JOIN dbo.Dim_ServiceType AS ServiceType
    ON ServiceType.ServiceCode = C.TaxiType

LEFT JOIN dbo.Dim_HVFHSProvider AS Provider
    ON Provider.LicenseNumber = C.HVFHSLicenseNum

LEFT JOIN dbo.Dim_Base AS DispatchBase
    ON DispatchBase.BaseNumber = C.DispatchingBaseNum

LEFT JOIN dbo.Dim_Base AS OriginBase
    ON OriginBase.BaseNumber = C.OriginatingBaseNum

LEFT JOIN dbo.Dim_HVFHVFlags AS Flags
    ON Flags.IsSharedRequest = C.NormalizedSharedRequest
   AND Flags.IsSharedMatch = C.NormalizedSharedMatch
   AND Flags.IsAccessARide = C.NormalizedAccessARide
   AND Flags.IsWAVRequest = C.NormalizedWAVRequest
   AND Flags.IsWAVMatch = C.NormalizedWAVMatch
LEFT JOIN dbo.Dim_LoadBatch AS LoadBatch
    ON LoadBatch.BatchID = CONCAT('CLEAN-',C.TaxiType,'-',CONVERT(char(6),C.PickupDateTime,112))

)

  SELECT * INTO #Desired FROM FactValues;
  CREATE UNIQUE CLUSTERED INDEX IX_Desired_Hash ON #Desired(RecordHash);
  IF (SELECT COUNT_BIG(*) FROM #Desired)<>@Expected
   THROW 55941,'File clean rows disagree with Transform checkpoint.',1;
  IF EXISTS(SELECT 1 FROM #Desired WHERE ServiceTypeKey=0)
   THROW 55942,'Unknown ServiceTypeKey in changed file.',1;
  INSERT etl.FactChangeAudit(TableName,RowJson)
   SELECT N'Fact_HVFHV_Trips',(SELECT F.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
   FROM dbo.Fact_HVFHV_Trips F
   WHERE F.SourceDataset=@Dataset AND F.SourceKey=@Source
     AND NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash);
  DELETE F FROM dbo.Fact_HVFHV_Trips F
   WHERE F.SourceDataset=@Dataset AND F.SourceKey=@Source
     AND NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash);
  SET @Deleted=@@ROWCOUNT;
  UPDATE F SET RequestDateKey=V.RequestDateKey,OnSceneDateKey=V.OnSceneDateKey,PickupDateKey=V.PickupDateKey,DropoffDateKey=V.DropoffDateKey,RequestTimeKey=V.RequestTimeKey,OnSceneTimeKey=V.OnSceneTimeKey,PickupTimeKey=V.PickupTimeKey,DropoffTimeKey=V.DropoffTimeKey,PickupLocationKey=V.PickupLocationKey,DropoffLocationKey=V.DropoffLocationKey,ServiceTypeKey=V.ServiceTypeKey,HVFHSProviderKey=V.HVFHSProviderKey,DispatchBaseKey=V.DispatchBaseKey,OriginBaseKey=V.OriginBaseKey,HVFHVFlagKey=V.HVFHVFlagKey,LoadBatchKey=V.LoadBatchKey,TripCount=V.TripCount,TripDistanceMiles=V.TripDistanceMiles,TripDurationSeconds=V.TripDurationSeconds,WaitingTimeSeconds=V.WaitingTimeSeconds,OnSceneToPickupSeconds=V.OnSceneToPickupSeconds,BasePassengerFare=V.BasePassengerFare,TollsAmount=V.TollsAmount,BCFAmount=V.BCFAmount,SalesTaxAmount=V.SalesTaxAmount,CongestionSurcharge=V.CongestionSurcharge,AirportFee=V.AirportFee,TipAmount=V.TipAmount,DriverPayAmount=V.DriverPayAmount,CBDCongestionFee=V.CBDCongestionFee,GrossPassengerAmount=V.GrossPassengerAmount,SourceDataset=V.SourceDataset,SourceKey=V.SourceKey
   FROM dbo.Fact_HVFHV_Trips F JOIN #Desired V ON V.RecordHash=F.RecordHash
   WHERE F.SourceDataset=@Dataset AND F.SourceKey=@Source
     AND EXISTS(SELECT F.RequestDateKey,F.OnSceneDateKey,F.PickupDateKey,F.DropoffDateKey,F.RequestTimeKey,F.OnSceneTimeKey,F.PickupTimeKey,F.DropoffTimeKey,F.PickupLocationKey,F.DropoffLocationKey,F.ServiceTypeKey,F.HVFHSProviderKey,F.DispatchBaseKey,F.OriginBaseKey,F.HVFHVFlagKey,F.LoadBatchKey,F.TripCount,F.TripDistanceMiles,F.TripDurationSeconds,F.WaitingTimeSeconds,F.OnSceneToPickupSeconds,F.BasePassengerFare,F.TollsAmount,F.BCFAmount,F.SalesTaxAmount,F.CongestionSurcharge,F.AirportFee,F.TipAmount,F.DriverPayAmount,F.CBDCongestionFee,F.GrossPassengerAmount,F.SourceDataset,F.SourceKey EXCEPT SELECT V.RequestDateKey,V.OnSceneDateKey,V.PickupDateKey,V.DropoffDateKey,V.RequestTimeKey,V.OnSceneTimeKey,V.PickupTimeKey,V.DropoffTimeKey,V.PickupLocationKey,V.DropoffLocationKey,V.ServiceTypeKey,V.HVFHSProviderKey,V.DispatchBaseKey,V.OriginBaseKey,V.HVFHVFlagKey,V.LoadBatchKey,V.TripCount,V.TripDistanceMiles,V.TripDurationSeconds,V.WaitingTimeSeconds,V.OnSceneToPickupSeconds,V.BasePassengerFare,V.TollsAmount,V.BCFAmount,V.SalesTaxAmount,V.CongestionSurcharge,V.AirportFee,V.TipAmount,V.DriverPayAmount,V.CBDCongestionFee,V.GrossPassengerAmount,V.SourceDataset,V.SourceKey);
  SET @Updated=@@ROWCOUNT;
    INSERT INTO dbo.Fact_HVFHV_Trips
    (RequestDateKey, OnSceneDateKey, PickupDateKey, DropoffDateKey, RequestTimeKey, OnSceneTimeKey, PickupTimeKey, DropoffTimeKey, PickupLocationKey, DropoffLocationKey, ServiceTypeKey, HVFHSProviderKey, DispatchBaseKey, OriginBaseKey, HVFHVFlagKey, LoadBatchKey, TripCount, TripDistanceMiles, TripDurationSeconds, WaitingTimeSeconds, OnSceneToPickupSeconds, BasePassengerFare, TollsAmount, BCFAmount, SalesTaxAmount, CongestionSurcharge, AirportFee, TipAmount, DriverPayAmount, CBDCongestionFee, GrossPassengerAmount, RecordHash, SourceDataset, SourceKey)
    SELECT V.RequestDateKey, V.OnSceneDateKey, V.PickupDateKey, V.DropoffDateKey, V.RequestTimeKey, V.OnSceneTimeKey, V.PickupTimeKey, V.DropoffTimeKey, V.PickupLocationKey, V.DropoffLocationKey, V.ServiceTypeKey, V.HVFHSProviderKey, V.DispatchBaseKey, V.OriginBaseKey, V.HVFHVFlagKey, V.LoadBatchKey, V.TripCount, V.TripDistanceMiles, V.TripDurationSeconds, V.WaitingTimeSeconds, V.OnSceneToPickupSeconds, V.BasePassengerFare, V.TollsAmount, V.BCFAmount, V.SalesTaxAmount, V.CongestionSurcharge, V.AirportFee, V.TipAmount, V.DriverPayAmount, V.CBDCongestionFee, V.GrossPassengerAmount, V.RecordHash, V.SourceDataset, V.SourceKey
    FROM #Desired V
    WHERE NOT EXISTS
      (SELECT 1 FROM dbo.Fact_HVFHV_Trips F WITH (UPDLOCK,HOLDLOCK) WHERE F.RecordHash=V.RecordHash);

  SET @Inserted=@@ROWCOUNT;
  IF TRY_CONVERT(int,SESSION_CONTEXT(N'NYCTaxiFailAfterFactWrite'))=1
   THROW 55949,'Injected failure after Fact write, before checkpoint.',1;
  SELECT @FactRows=COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips WHERE SourceDataset=@Dataset AND SourceKey=@Source;
  IF @FactRows<>@Expected THROW 55943,'File Fact reconciliation failed.',1;
  SELECT @Unknown=COALESCE(MAX(UnresolvedMask&1),0)+COALESCE(MAX(UnresolvedMask&2),0)+COALESCE(MAX(UnresolvedMask&4),0) FROM #Desired;
  DELETE etl.DwhFileLog WHERE DatasetCode=@Dataset AND SourceKey=@Source;
  INSERT etl.DwhFileLog(DatasetCode,SourceKey,SourceVersion,LoaderVersion,Status,ForceReload,
   ValidRows,FactRows,InsertedRows,UpdatedRows,DeletedRows,UnknownMask,LocationMapHash,BaseMapHash,OtherMapHash,CompletedAt)
  VALUES(@Dataset,@Source,@Token,'FILE_V1_20261031','SUCCEEDED',0,@Expected,@FactRows,@Inserted,@Updated,@Deleted,@Unknown,
   @LocationMapHash,@BaseMapHash,@OtherMapHash,SYSUTCDATETIME());
  INSERT etl.LoadStepLog(StepName,InsertedRows) VALUES(N'Fact_HVFHV_Trips',@Inserted);
  COMMIT TRANSACTION;
  SET @Files+=1; SET @Input+=@Expected;
 END TRY
 BEGIN CATCH
  SET @Error=ERROR_MESSAGE(); IF @@TRANCOUNT>0 ROLLBACK;
  IF NOT EXISTS(SELECT 1 FROM etl.DwhFileLog WHERE DatasetCode=@Dataset AND SourceKey=@Source)
   INSERT etl.DwhFileLog(DatasetCode,SourceKey,Status,ErrorMessage) VALUES(@Dataset,@Source,'FAILED',@Error);
  ELSE UPDATE etl.DwhFileLog SET Status='FAILED',ErrorMessage=@Error WHERE DatasetCode=@Dataset AND SourceKey=@Source;
  CLOSE FileCursor; DEALLOCATE FileCursor; THROW;
 END CATCH;
 FETCH NEXT FROM FileCursor INTO @Dataset,@Source,@Expected,@Token;
END;
CLOSE FileCursor; DEALLOCATE FileCursor;
DROP TABLE IF EXISTS #Desired; DROP TABLE IF EXISTS #CurrentFile; DROP TABLE #DwhTodo;
SELECT @Files AS ProcessedFiles,@Input AS ValidInputRows;

SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
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
  WHERE C.TaxiType='FHV'
),
Ranked AS
(
  SELECT S.*, ROW_NUMBER() OVER(PARTITION BY S.PayloadHash ORDER BY S.TripCleanID) AS DuplicateOrdinal
  FROM SourceRows S
),
Tagged AS
(
  SELECT R.*,
    HASHBYTES('SHA2_256', CONCAT(CONVERT(varchar(64),R.PayloadHash,2),':',R.DuplicateOrdinal)) AS RecordHash
  FROM Ranked R
),
FactValues AS (
SELECT
    COALESCE(PickupDate.DateKey, 0) AS PickupDateKey,
    COALESCE(DropoffDate.DateKey, 0) AS DropoffDateKey,

    COALESCE(PickupTime.TimeKey, 0) AS PickupTimeKey,
    COALESCE(DropoffTime.TimeKey, 0) AS DropoffTimeKey,

    COALESCE(PickupZone.LocationKey, 0)
        AS PickupLocationKey,

    COALESCE(DropoffZone.LocationKey, 0)
        AS DropoffLocationKey,

    COALESCE(ServiceType.ServiceTypeKey, 0)
        AS ServiceTypeKey,

    COALESCE(DispatchBase.BaseKey, 0)
        AS DispatchBaseKey,

    COALESCE(AffiliatedBase.BaseKey, 0)
        AS AffiliatedBaseKey,

    COALESCE(FHVFlag.FHVFlagKey, 0)
        AS FHVFlagKey,

    COALESCE(LoadBatch.LoadBatchKey,0) AS LoadBatchKey,
    1 AS TripCount,

    C.TripDurationSeconds,
    C.RecordHash AS RecordHash, LOWER(C.TaxiType) AS SourceDataset, C.ETLSourceKey AS SourceKey

FROM Tagged AS C

LEFT JOIN dbo.Dim_Date AS PickupDate
    ON PickupDate.FullDate =
       CONVERT(DATE, C.PickupDateTime)

LEFT JOIN dbo.Dim_Date AS DropoffDate
    ON DropoffDate.FullDate =
       CONVERT(DATE, C.DropoffDateTime)

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

LEFT JOIN dbo.Dim_Base AS DispatchBase
    ON DispatchBase.BaseNumber = C.DispatchingBaseNum

LEFT JOIN dbo.Dim_Base AS AffiliatedBase
    ON AffiliatedBase.BaseNumber = C.AffiliatedBaseNum

LEFT JOIN dbo.Dim_FHVFlags AS FHVFlag
    ON FHVFlag.IsSharedRide =
       CASE
           WHEN UPPER(C.SharedRequestFlag) IN ('Y', 'N')
               THEN UPPER(C.SharedRequestFlag)
           ELSE 'U'
       END

LEFT JOIN dbo.Dim_LoadBatch AS LoadBatch
    ON LoadBatch.BatchID = CONCAT('CLEAN-',C.TaxiType,'-',CONVERT(char(6),C.PickupDateTime,112))

WHERE C.TaxiType = 'FHV'
)
    SELECT * INTO #Desired FROM FactValues;
    CREATE UNIQUE CLUSTERED INDEX IX_Desired_Hash ON #Desired(RecordHash);
    IF EXISTS(SELECT 1 FROM #Desired WHERE SourceKey IS NULL)
        THROW 55910,'Clean source lineage is missing; refusing fact reconciliation.',1;
    UPDATE F SET SourceDataset=V.SourceDataset,SourceKey=V.SourceKey
      FROM dbo.Fact_FHV_Trips F JOIN #Desired V ON V.RecordHash=F.RecordHash
      WHERE F.SourceKey IS NULL OR F.SourceKey<>V.SourceKey OR F.SourceDataset<>V.SourceDataset;
    IF EXISTS(SELECT 1 FROM dbo.Fact_FHV_Trips WHERE SourceKey IS NULL)
        THROW 55911,'Unmapped legacy facts exist. Restore clean history or perform reviewed migration; no automatic deletion.',1;
    INSERT etl.FactChangeAudit(TableName,RowJson)
      SELECT N'Fact_FHV_Trips',(SELECT F.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
      FROM dbo.Fact_FHV_Trips F
      WHERE NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash)
        AND EXISTS(SELECT 1 FROM NYCTaxi_Staging.etl.ExtractFileLog L
          WHERE L.DatasetCode=F.SourceDataset AND L.SourceKey=F.SourceKey AND L.LoadStatus='SUCCEEDED');
    DELETE F FROM dbo.Fact_FHV_Trips F
      WHERE NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash)
        AND EXISTS(SELECT 1 FROM NYCTaxi_Staging.etl.ExtractFileLog L
          WHERE L.DatasetCode=F.SourceDataset AND L.SourceKey=F.SourceKey AND L.LoadStatus='SUCCEEDED');
    UPDATE F SET PickupDateKey=V.PickupDateKey,DropoffDateKey=V.DropoffDateKey,PickupTimeKey=V.PickupTimeKey,DropoffTimeKey=V.DropoffTimeKey,PickupLocationKey=V.PickupLocationKey,DropoffLocationKey=V.DropoffLocationKey,ServiceTypeKey=V.ServiceTypeKey,DispatchBaseKey=V.DispatchBaseKey,AffiliatedBaseKey=V.AffiliatedBaseKey,FHVFlagKey=V.FHVFlagKey,LoadBatchKey=V.LoadBatchKey,TripCount=V.TripCount,TripDurationSeconds=V.TripDurationSeconds,SourceDataset=V.SourceDataset,SourceKey=V.SourceKey FROM dbo.Fact_FHV_Trips F JOIN #Desired V ON V.RecordHash=F.RecordHash WHERE EXISTS (SELECT F.PickupDateKey,F.DropoffDateKey,F.PickupTimeKey,F.DropoffTimeKey,F.PickupLocationKey,F.DropoffLocationKey,F.ServiceTypeKey,F.DispatchBaseKey,F.AffiliatedBaseKey,F.FHVFlagKey,F.LoadBatchKey,F.TripCount,F.TripDurationSeconds,F.SourceDataset,F.SourceKey EXCEPT SELECT V.PickupDateKey,V.DropoffDateKey,V.PickupTimeKey,V.DropoffTimeKey,V.PickupLocationKey,V.DropoffLocationKey,V.ServiceTypeKey,V.DispatchBaseKey,V.AffiliatedBaseKey,V.FHVFlagKey,V.LoadBatchKey,V.TripCount,V.TripDurationSeconds,V.SourceDataset,V.SourceKey);
    INSERT INTO dbo.Fact_FHV_Trips
    (PickupDateKey, DropoffDateKey, PickupTimeKey, DropoffTimeKey, PickupLocationKey, DropoffLocationKey, ServiceTypeKey, DispatchBaseKey, AffiliatedBaseKey, FHVFlagKey, LoadBatchKey, TripCount, TripDurationSeconds, RecordHash, SourceDataset, SourceKey)
    SELECT V.PickupDateKey, V.DropoffDateKey, V.PickupTimeKey, V.DropoffTimeKey, V.PickupLocationKey, V.DropoffLocationKey, V.ServiceTypeKey, V.DispatchBaseKey, V.AffiliatedBaseKey, V.FHVFlagKey, V.LoadBatchKey, V.TripCount, V.TripDurationSeconds, V.RecordHash, V.SourceDataset, V.SourceKey
    FROM #Desired V
    WHERE NOT EXISTS
      (SELECT 1 FROM dbo.Fact_FHV_Trips F WITH (UPDLOCK,HOLDLOCK) WHERE F.RecordHash=V.RecordHash);
    DECLARE @InsertedRows bigint = @@ROWCOUNT;
    INSERT etl.LoadStepLog(StepName,InsertedRows)
    VALUES('Fact_FHV_Trips',@InsertedRows);

 DROP TABLE #Desired;
 COMMIT TRAN;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;

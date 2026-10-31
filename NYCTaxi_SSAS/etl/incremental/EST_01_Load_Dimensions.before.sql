SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 -- All physical Dimension tables and their Unknown members come from 04_create_nyctaxi_dwh.sql.
 -- 1) SCD Type 1: Taxi Zone lookup
 INSERT INTO dbo.Dim_Location(LocationID,Borough,ZoneName,ServiceZone)
 SELECT S.LocationID,S.Borough,S.Zone,S.ServiceZone
 FROM NYCTaxi_Staging.clean.TaxiZone S
 WHERE S.LocationID IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM dbo.Dim_Location D WITH (UPDLOCK,HOLDLOCK) WHERE D.LocationID=S.LocationID);
 UPDATE D SET D.Borough=S.Borough, D.ZoneName=S.Zone, D.ServiceZone=S.ServiceZone
 FROM dbo.Dim_Location D JOIN NYCTaxi_Staging.clean.TaxiZone S ON S.LocationID=D.LocationID
 WHERE EXISTS (SELECT D.Borough,D.ZoneName,D.ServiceZone EXCEPT SELECT S.Borough,S.Zone,S.ServiceZone);
 -- 2) Codes used by all four source types
 INSERT dbo.Dim_ServiceType(ServiceCode,ServiceName)
 SELECT V.Code,V.Name
 FROM (VALUES ('YELLOW',N'Yellow Taxi'),('GREEN',N'Green Taxi'),
              ('FHV',N'For-Hire Vehicle'),('FHVHV',N'High Volume FHV')) V(Code,Name)
 WHERE NOT EXISTS(SELECT 1 FROM dbo.Dim_ServiceType D WHERE D.ServiceCode=V.Code);
 INSERT dbo.Dim_Vendor(VendorID)
 SELECT DISTINCT C.VendorID FROM NYCTaxi_Staging.clean.ValidTrip C
 WHERE C.TaxiType IN('YELLOW','GREEN') AND C.VendorID IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM dbo.Dim_Vendor D WHERE D.VendorID=C.VendorID);
 INSERT dbo.Dim_RateCode(RateCodeID)
 SELECT DISTINCT C.RateCodeID FROM NYCTaxi_Staging.clean.ValidTrip C
 WHERE C.TaxiType IN('YELLOW','GREEN') AND C.RateCodeID IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM dbo.Dim_RateCode D WHERE D.RateCodeID=C.RateCodeID);
 INSERT dbo.Dim_PaymentType(PaymentTypeID)
 SELECT DISTINCT C.PaymentTypeID FROM NYCTaxi_Staging.clean.ValidTrip C
 WHERE C.TaxiType IN('YELLOW','GREEN') AND C.PaymentTypeID IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM dbo.Dim_PaymentType D WHERE D.PaymentTypeID=C.PaymentTypeID);
 INSERT dbo.Dim_TripType(TripTypeID)
 SELECT DISTINCT C.TripTypeID FROM NYCTaxi_Staging.clean.ValidTrip C
 WHERE C.TaxiType='GREEN' AND C.TripTypeID IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM dbo.Dim_TripType D WHERE D.TripTypeID=C.TripTypeID);
 INSERT dbo.Dim_HVFHSProvider(LicenseNumber)
 SELECT DISTINCT C.HVFHSLicenseNum FROM NYCTaxi_Staging.clean.ValidTrip C
 WHERE C.TaxiType='FHVHV' AND C.HVFHSLicenseNum IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM dbo.Dim_HVFHSProvider D WHERE D.LicenseNumber=C.HVFHSLicenseNum);
 ;WITH Bases AS
 (
   SELECT DispatchingBaseNum AS BaseNumber FROM NYCTaxi_Staging.clean.ValidTrip
   UNION SELECT OriginatingBaseNum FROM NYCTaxi_Staging.clean.ValidTrip
   UNION SELECT AffiliatedBaseNum FROM NYCTaxi_Staging.clean.ValidTrip
 )
 INSERT dbo.Dim_Base(BaseNumber)
 SELECT B.BaseNumber FROM Bases B
 WHERE B.BaseNumber IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM dbo.Dim_Base D WHERE D.BaseNumber=B.BaseNumber);
 -- 3) Junk dimensions
 INSERT dbo.Dim_TaxiFlags(StoreAndFwd)
 SELECT DISTINCT CASE WHEN UPPER(C.StoreAndFwdFlag) IN('Y','N') THEN UPPER(C.StoreAndFwdFlag) ELSE 'U' END
 FROM NYCTaxi_Staging.clean.ValidTrip C WHERE C.TaxiType IN('YELLOW','GREEN')
 AND NOT EXISTS (SELECT 1 FROM dbo.Dim_TaxiFlags D
     WHERE D.StoreAndFwd=CASE WHEN UPPER(C.StoreAndFwdFlag) IN('Y','N') THEN UPPER(C.StoreAndFwdFlag) ELSE 'U' END);
 INSERT dbo.Dim_FHVFlags(IsSharedRide)
 SELECT DISTINCT CASE WHEN UPPER(C.SharedRequestFlag) IN('Y','N') THEN UPPER(C.SharedRequestFlag) ELSE 'U' END
 FROM NYCTaxi_Staging.clean.ValidTrip C WHERE C.TaxiType='FHV'
 AND NOT EXISTS (SELECT 1 FROM dbo.Dim_FHVFlags D
     WHERE D.IsSharedRide=CASE WHEN UPPER(C.SharedRequestFlag) IN('Y','N') THEN UPPER(C.SharedRequestFlag) ELSE 'U' END);
 ;WITH F AS
 (
   SELECT DISTINCT
    CASE WHEN UPPER(SharedRequestFlag) IN('Y','N') THEN UPPER(SharedRequestFlag) ELSE 'U' END AS R,
    CASE WHEN UPPER(SharedMatchFlag) IN('Y','N') THEN UPPER(SharedMatchFlag) ELSE 'U' END AS M,
    CASE WHEN UPPER(AccessARideFlag) IN('Y','N') THEN UPPER(AccessARideFlag) ELSE 'U' END AS A,
    CASE WHEN UPPER(WAVRequestFlag) IN('Y','N') THEN UPPER(WAVRequestFlag) ELSE 'U' END AS WR,
    CASE WHEN UPPER(WAVMatchFlag) IN('Y','N') THEN UPPER(WAVMatchFlag) ELSE 'U' END AS WM
   FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType='FHVHV'
 )
 INSERT dbo.Dim_HVFHVFlags(IsSharedRequest,IsSharedMatch,IsAccessARide,IsWAVRequest,IsWAVMatch)
 SELECT F.R,F.M,F.A,F.WR,F.WM FROM F
 WHERE NOT EXISTS (SELECT 1 FROM dbo.Dim_HVFHVFlags D
    WHERE D.IsSharedRequest=F.R AND D.IsSharedMatch=F.M AND D.IsAccessARide=F.A
    AND D.IsWAVRequest=F.WR AND D.IsWAVMatch=F.WM);
 -- 4) Add dates outside seed period; IsHoliday=0 until a reliable calendar is provided.
 ;WITH Dates AS
 (
    SELECT CONVERT(date,PickupDateTime) AS FullDate FROM NYCTaxi_Staging.clean.ValidTrip
    UNION SELECT CONVERT(date,DropoffDateTime) FROM NYCTaxi_Staging.clean.ValidTrip
    UNION SELECT CONVERT(date,RequestDateTime) FROM NYCTaxi_Staging.clean.ValidTrip WHERE RequestDateTime IS NOT NULL
    UNION SELECT CONVERT(date,OnSceneDateTime) FROM NYCTaxi_Staging.clean.ValidTrip WHERE OnSceneDateTime IS NOT NULL
 )
 INSERT dbo.Dim_Date(DateKey,FullDate,DayOfWeekNumber,DayOfWeekName,DayOfMonth,MonthNumber,
                      MonthName,QuarterNumber,YearNumber,IsWeekend,IsHoliday)
 SELECT YEAR(X.FullDate)*10000+MONTH(X.FullDate)*100+DAY(X.FullDate),X.FullDate,
        CONVERT(tinyint,DATEDIFF(DAY,'19000101',X.FullDate)%7+1),
        DATENAME(WEEKDAY,X.FullDate),CONVERT(tinyint,DAY(X.FullDate)),
        CONVERT(tinyint,MONTH(X.FullDate)),DATENAME(MONTH,X.FullDate),
        CONVERT(tinyint,DATEPART(QUARTER,X.FullDate)),CONVERT(smallint,YEAR(X.FullDate)),
        CASE WHEN DATEDIFF(DAY,'19000101',X.FullDate)%7 IN(5,6) THEN 1 ELSE 0 END,0
 FROM Dates X WHERE X.FullDate BETWEEN '20000101' AND '20991231'
 AND NOT EXISTS(SELECT 1 FROM dbo.Dim_Date D WHERE D.FullDate=X.FullDate);
 -- 5) Monthly processing groups inferred from pickup dates (NOT actual file lineage).
 ;WITH B AS
 (
    SELECT DISTINCT C.TaxiType,
         YEAR(C.PickupDateTime) AS YY,MONTH(C.PickupDateTime) AS MM,
         CONCAT('CLEAN-',C.TaxiType,'-',CONVERT(char(6),C.PickupDateTime,112)) AS BatchID
    FROM NYCTaxi_Staging.clean.ValidTrip C
    WHERE C.PickupDateTime IS NOT NULL
 )
 INSERT dbo.Dim_LoadBatch(BatchID,DatasetName,SourceFileName,SourceYear,SourceMonth,LoadedAt,BatchStatus)
 SELECT B.BatchID,B.TaxiType,NULL,B.YY,B.MM,SYSDATETIME(),'READY'
 FROM B WHERE NOT EXISTS(SELECT 1 FROM dbo.Dim_LoadBatch D WHERE D.BatchID=B.BatchID);
 COMMIT TRAN;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;

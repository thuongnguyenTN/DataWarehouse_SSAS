SET NOCOUNT ON;
-- Source can be a subset of historical data, so only compare a lower bound.
DECLARE @CleanTaxi bigint=(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType IN('YELLOW','GREEN'));
DECLARE @CleanFHV bigint=(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType='FHV');
DECLARE @CleanHVFHV bigint=(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType='FHVHV');
IF (SELECT COUNT_BIG(*) FROM dbo.Fact_YellowGreen_Trips)<@CleanTaxi
 THROW 55041,'YellowGreen Fact is missing valid Clean trips.',1;
IF (SELECT COUNT_BIG(*) FROM dbo.Fact_FHV_Trips)<@CleanFHV
 THROW 55042,'FHV Fact is missing valid Clean trips.',1;
IF (SELECT COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips)<@CleanHVFHV
 THROW 55043,'HVFHV Fact is missing valid Clean trips.',1;
IF EXISTS (SELECT 1 FROM dbo.Fact_YellowGreen_Trips WHERE ServiceTypeKey=0)
 OR EXISTS (SELECT 1 FROM dbo.Fact_FHV_Trips WHERE ServiceTypeKey=0)
 OR EXISTS (SELECT 1 FROM dbo.Fact_HVFHV_Trips WHERE ServiceTypeKey=0)
 THROW 55044, 'A Fact has unknown ServiceTypeKey.',1;
-- Mark inferred monthly groups, without asserting any real file-level lineage.
UPDATE D SET D.BatchStatus='SUCCEEDED',D.LoadedAt=SYSDATETIME()
FROM dbo.Dim_LoadBatch D
WHERE D.BatchID LIKE 'CLEAN-%' AND D.BatchStatus='READY';

IF (SELECT COUNT_BIG(*) FROM dbo.Fact_YellowGreen_Trips)<>(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType IN('YELLOW','GREEN'))
 OR (SELECT COUNT_BIG(*) FROM dbo.Fact_FHV_Trips)<>(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType='FHV')
 OR (SELECT COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips)<>(SELECT COUNT_BIG(*) FROM NYCTaxi_Staging.clean.ValidTrip WHERE TaxiType='FHVHV')
 THROW 55912,'Exact clean-to-fact row reconciliation failed.',1;

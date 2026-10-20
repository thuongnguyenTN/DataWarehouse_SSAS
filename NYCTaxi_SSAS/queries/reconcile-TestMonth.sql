-- FHV trips
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV date 20250101
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupDateKey=20250101 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV date 20250115
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupDateKey=20250115 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV pickup location 0
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=0 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV pickup location 1
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV pickup location 132
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=132 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV pickup location 138
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=138 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV borough Manhattan
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Manhattan' AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV borough Queens
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Queens' AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- FHV avg duration
SELECT SUM(CAST(TripDurationSeconds AS float))/NULLIF(SUM(CASE WHEN TripDurationSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_FHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV trips
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV date 20250101
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupDateKey=20250101 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV date 20250115
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupDateKey=20250115 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV pickup location 0
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=0 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV pickup location 1
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV pickup location 132
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=132 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV pickup location 138
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=138 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV borough Manhattan
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Manhattan' AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV borough Queens
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Queens' AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV avg duration
SELECT SUM(CAST(TripDurationSeconds AS float))/NULLIF(SUM(CASE WHEN TripDurationSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV avg distance
SELECT SUM(TripDistanceMiles)/NULLIF(SUM(CASE WHEN TripDistanceMiles IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV speed
SELECT SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDistanceMiles AS float) END)/NULLIF(SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDurationSeconds AS float) END),0)*3600 FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV avg fare
SELECT SUM(BasePassengerFare)/NULLIF(SUM(CASE WHEN BasePassengerFare IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV avg tip
SELECT SUM(TipAmount)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV tip percentage
SELECT SUM(CASE WHEN TipAmount IS NOT NULL AND BasePassengerFare IS NOT NULL THEN TipAmount END)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL AND BasePassengerFare IS NOT NULL THEN BasePassengerFare END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen trips
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen date 20250101
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey=20250101 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen date 20250115
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey=20250115 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen pickup location 0
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=0 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen pickup location 1
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen pickup location 132
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=132 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen pickup location 138
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=138 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen borough Manhattan
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Manhattan' AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen borough Queens
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Queens' AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen avg duration
SELECT SUM(CAST(TripDurationSeconds AS float))/NULLIF(SUM(CASE WHEN TripDurationSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen avg distance
SELECT SUM(TripDistanceMiles)/NULLIF(SUM(CASE WHEN TripDistanceMiles IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen speed
SELECT SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDistanceMiles AS float) END)/NULLIF(SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDurationSeconds AS float) END),0)*3600 FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen avg fare
SELECT SUM(FareAmount)/NULLIF(SUM(CASE WHEN FareAmount IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen avg tip
SELECT SUM(TipAmount)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen tip percentage
SELECT SUM(CASE WHEN TipAmount IS NOT NULL AND FareAmount IS NOT NULL THEN TipAmount END)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL AND FareAmount IS NOT NULL THEN FareAmount END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- Service YELLOW
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE ServiceTypeKey=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- Service GREEN
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE ServiceTypeKey=2 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- Service FHV
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE ServiceTypeKey=3 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- Service FHVHV
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE ServiceTypeKey=4 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- YellowGreen revenue
SELECT SUM(TotalAmount) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV driver pay
SELECT SUM(DriverPayAmount) FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- HVFHV avg waiting
SELECT SUM(CAST(WaitingTimeSeconds AS float))/NULLIF(SUM(CASE WHEN WaitingTimeSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_HVFHV_Trips WHERE 1=1 AND PickupDateKey>=20250101 AND PickupDateKey<20250201;

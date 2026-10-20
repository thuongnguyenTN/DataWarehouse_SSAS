-- FHV trips
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE 1=1;
-- FHV date 20250101
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupDateKey=20250101;
-- FHV date 20250115
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupDateKey=20250115;
-- FHV pickup location 0
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=0;
-- FHV pickup location 1
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=1;
-- FHV pickup location 132
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=132;
-- FHV pickup location 138
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupLocationKey=138;
-- FHV borough Manhattan
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Manhattan';
-- FHV borough Queens
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Queens';
-- FHV avg duration
SELECT SUM(CAST(TripDurationSeconds AS float))/NULLIF(SUM(CASE WHEN TripDurationSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_FHV_Trips WHERE 1=1;
-- HVFHV trips
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- HVFHV date 20250101
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupDateKey=20250101;
-- HVFHV date 20250115
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupDateKey=20250115;
-- HVFHV pickup location 0
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=0;
-- HVFHV pickup location 1
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=1;
-- HVFHV pickup location 132
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=132;
-- HVFHV pickup location 138
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupLocationKey=138;
-- HVFHV borough Manhattan
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Manhattan';
-- HVFHV borough Queens
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Queens';
-- HVFHV avg duration
SELECT SUM(CAST(TripDurationSeconds AS float))/NULLIF(SUM(CASE WHEN TripDurationSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- HVFHV avg distance
SELECT SUM(TripDistanceMiles)/NULLIF(SUM(CASE WHEN TripDistanceMiles IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- HVFHV speed
SELECT SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDistanceMiles AS float) END)/NULLIF(SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDurationSeconds AS float) END),0)*3600 FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- HVFHV avg fare
SELECT SUM(BasePassengerFare)/NULLIF(SUM(CASE WHEN BasePassengerFare IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- HVFHV avg tip
SELECT SUM(TipAmount)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- HVFHV tip percentage
SELECT SUM(CASE WHEN TipAmount IS NOT NULL AND BasePassengerFare IS NOT NULL THEN TipAmount END)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL AND BasePassengerFare IS NOT NULL THEN BasePassengerFare END),0) FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- YellowGreen trips
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- YellowGreen date 20250101
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey=20250101;
-- YellowGreen date 20250115
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey=20250115;
-- YellowGreen pickup location 0
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=0;
-- YellowGreen pickup location 1
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=1;
-- YellowGreen pickup location 132
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=132;
-- YellowGreen pickup location 138
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupLocationKey=138;
-- YellowGreen borough Manhattan
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Manhattan';
-- YellowGreen borough Queens
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips f JOIN dbo.Dim_Location d ON f.PickupLocationKey=d.LocationKey WHERE d.Borough=N'Queens';
-- YellowGreen avg duration
SELECT SUM(CAST(TripDurationSeconds AS float))/NULLIF(SUM(CASE WHEN TripDurationSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- YellowGreen avg distance
SELECT SUM(TripDistanceMiles)/NULLIF(SUM(CASE WHEN TripDistanceMiles IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- YellowGreen speed
SELECT SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDistanceMiles AS float) END)/NULLIF(SUM(CASE WHEN TripDurationSeconds>0 AND TripDistanceMiles>=0 THEN CAST(TripDurationSeconds AS float) END),0)*3600 FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- YellowGreen avg fare
SELECT SUM(FareAmount)/NULLIF(SUM(CASE WHEN FareAmount IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- YellowGreen avg tip
SELECT SUM(TipAmount)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- YellowGreen tip percentage
SELECT SUM(CASE WHEN TipAmount IS NOT NULL AND FareAmount IS NOT NULL THEN TipAmount END)/NULLIF(SUM(CASE WHEN TipAmount IS NOT NULL AND FareAmount IS NOT NULL THEN FareAmount END),0) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- Service YELLOW
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE ServiceTypeKey=1;
-- Service GREEN
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE ServiceTypeKey=2;
-- Service FHV
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE ServiceTypeKey=3;
-- Service FHVHV
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE ServiceTypeKey=4;
-- YellowGreen revenue
SELECT SUM(TotalAmount) FROM dbo.Fact_YellowGreen_Trips WHERE 1=1;
-- HVFHV driver pay
SELECT SUM(DriverPayAmount) FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- HVFHV avg waiting
SELECT SUM(CAST(WaitingTimeSeconds AS float))/NULLIF(SUM(CASE WHEN WaitingTimeSeconds IS NOT NULL THEN CAST(TripCount AS bigint) ELSE 0 END),0)/60.0 FROM dbo.Fact_HVFHV_Trips WHERE 1=1;
-- Daily Financial Snapshot TotalTrips
SELECT SUM(TotalTrips) FROM dbo.Fact_Daily_Financial_Snapshot;
-- Daily Financial Snapshot TotalDistanceMiles
SELECT SUM(TotalDistanceMiles) FROM dbo.Fact_Daily_Financial_Snapshot;
-- Daily Financial Snapshot TotalPassengerCharges
SELECT SUM(TotalPassengerCharges) FROM dbo.Fact_Daily_Financial_Snapshot;
-- Daily Financial Snapshot TotalTips
SELECT SUM(TotalTips) FROM dbo.Fact_Daily_Financial_Snapshot;
-- Daily Financial Snapshot TotalTaxesAndFees
SELECT SUM(TotalTaxesAndFees) FROM dbo.Fact_Daily_Financial_Snapshot;
-- Daily Financial Snapshot TotalDriverPay
SELECT SUM(TotalDriverPay) FROM dbo.Fact_Daily_Financial_Snapshot;
-- Zone Traffic Snapshot TotalPickups
SELECT SUM(TotalPickups) FROM dbo.Fact_Zone_Traffic_Snapshot;
-- Zone Traffic Snapshot TotalDropoffs
SELECT SUM(TotalDropoffs) FROM dbo.Fact_Zone_Traffic_Snapshot;
-- Base Performance Snapshot TotalTrips
SELECT SUM(TotalTrips) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot TotalTripDurationSeconds
SELECT SUM(TotalTripDurationSeconds) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot DurationTripCount
SELECT SUM(DurationTripCount) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot TotalWaitingTimeSeconds
SELECT SUM(TotalWaitingTimeSeconds) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot WaitingTripCount
SELECT SUM(WaitingTripCount) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot TotalSharedRequests
SELECT SUM(TotalSharedRequests) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot TotalSharedMatches
SELECT SUM(TotalSharedMatches) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot TotalWAVRequests
SELECT SUM(TotalWAVRequests) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot TotalWAVMatches
SELECT SUM(TotalWAVMatches) FROM dbo.Fact_Base_Performance_Snapshot;
-- Base Performance Snapshot TotalDriverPay
SELECT SUM(TotalDriverPay) FROM dbo.Fact_Base_Performance_Snapshot;
-- Shared request rate
SELECT SUM(CAST(TotalSharedRequests AS float))/NULLIF(SUM(TotalTrips),0) FROM dbo.Fact_Base_Performance_Snapshot WHERE ServiceTypeKey=4;
-- WAV match rate
SELECT SUM(CAST(TotalWAVMatches AS float))/NULLIF(SUM(TotalWAVRequests),0) FROM dbo.Fact_Base_Performance_Snapshot;
-- Dispatch base 0
SELECT SUM(TotalTrips) FROM dbo.Fact_Base_Performance_Snapshot WHERE DispatchBaseKey=0;
-- Dispatch base 1
SELECT SUM(TotalTrips) FROM dbo.Fact_Base_Performance_Snapshot WHERE DispatchBaseKey=1;
-- Dispatch base 2
SELECT SUM(TotalTrips) FROM dbo.Fact_Base_Performance_Snapshot WHERE DispatchBaseKey=2;
-- Dispatch base 3
SELECT SUM(TotalTrips) FROM dbo.Fact_Base_Performance_Snapshot WHERE DispatchBaseKey=3;
-- Base avg duration
SELECT SUM(CAST(TotalTripDurationSeconds AS float))/NULLIF(SUM(DurationTripCount),0)/60.0 FROM dbo.Fact_Base_Performance_Snapshot;
-- Base avg waiting
SELECT SUM(CAST(TotalWaitingTimeSeconds AS float))/NULLIF(SUM(WaitingTripCount),0)/60.0 FROM dbo.Fact_Base_Performance_Snapshot;
-- Snapshot pickups date 20250101
SELECT SUM(TotalPickups) FROM dbo.Fact_Zone_Traffic_Snapshot WHERE DateKey=20250101;
-- Snapshot pickups date 20250115
SELECT SUM(TotalPickups) FROM dbo.Fact_Zone_Traffic_Snapshot WHERE DateKey=20250115;
-- Snapshot dropoffs location 0
SELECT SUM(TotalDropoffs) FROM dbo.Fact_Zone_Traffic_Snapshot WHERE LocationKey=0;
-- Snapshot dropoffs location 1
SELECT SUM(TotalDropoffs) FROM dbo.Fact_Zone_Traffic_Snapshot WHERE LocationKey=1;
-- Snapshot dropoffs location 132
SELECT SUM(TotalDropoffs) FROM dbo.Fact_Zone_Traffic_Snapshot WHERE LocationKey=132;
-- Fact_FHV_Trips Unknown batch
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE LoadBatchKey=0;
-- Fact_FHV_Trips Unknown time
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupTimeKey=0;
-- Fact_FHV_Trips Unknown date
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupDateKey=0;
-- Fact_FHV_Trips hour 0
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=0 AND t.TimeKey>0;
-- Fact_FHV_Trips hour 8
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=8 AND t.TimeKey>0;
-- Fact_FHV_Trips hour 17
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_FHV_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=17 AND t.TimeKey>0;
-- Fact_FHV_Trips calendar Jan2025
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- Fact_FHV_Trips calendar Q12025
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_FHV_Trips WHERE PickupDateKey>=20250101 AND PickupDateKey<20250401;
-- Fact_HVFHV_Trips Unknown batch
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE LoadBatchKey=0;
-- Fact_HVFHV_Trips Unknown time
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupTimeKey=0;
-- Fact_HVFHV_Trips Unknown date
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupDateKey=0;
-- Fact_HVFHV_Trips hour 0
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=0 AND t.TimeKey>0;
-- Fact_HVFHV_Trips hour 8
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=8 AND t.TimeKey>0;
-- Fact_HVFHV_Trips hour 17
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=17 AND t.TimeKey>0;
-- Fact_HVFHV_Trips calendar Jan2025
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- Fact_HVFHV_Trips calendar Q12025
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_HVFHV_Trips WHERE PickupDateKey>=20250101 AND PickupDateKey<20250401;
-- Fact_YellowGreen_Trips Unknown batch
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE LoadBatchKey=0;
-- Fact_YellowGreen_Trips Unknown time
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupTimeKey=0;
-- Fact_YellowGreen_Trips Unknown date
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey=0;
-- Fact_YellowGreen_Trips hour 0
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=0 AND t.TimeKey>0;
-- Fact_YellowGreen_Trips hour 8
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=8 AND t.TimeKey>0;
-- Fact_YellowGreen_Trips hour 17
SELECT SUM(CAST(f.TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips f JOIN dbo.Dim_Time t ON f.PickupTimeKey=t.TimeKey WHERE t.HourNumber=17 AND t.TimeKey>0;
-- Fact_YellowGreen_Trips calendar Jan2025
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey>=20250101 AND PickupDateKey<20250201;
-- Fact_YellowGreen_Trips calendar Q12025
SELECT SUM(CAST(TripCount AS bigint)) FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey>=20250101 AND PickupDateKey<20250401;

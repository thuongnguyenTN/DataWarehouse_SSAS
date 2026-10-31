USE NYCTaxi_DWH;
GO
-- Run before and after ETL. A source file may contain pickup dates outside its named month.
SELECT 'YellowGreen' AS Dataset, COUNT_BIG(*) AS TripsInJanuary2013
FROM dbo.Fact_YellowGreen_Trips WHERE PickupDateKey >= 20130101 AND PickupDateKey < 20130201
UNION ALL
SELECT 'FHV', COUNT_BIG(*) FROM dbo.Fact_FHV_Trips
WHERE PickupDateKey >= 20130101 AND PickupDateKey < 20130201
UNION ALL
SELECT 'HVFHV', COUNT_BIG(*) FROM dbo.Fact_HVFHV_Trips
WHERE PickupDateKey >= 20130101 AND PickupDateKey < 20130201;

SELECT SourceDataset, SourceKey, COUNT_BIG(*) AS LoadedFacts,
       MIN(PickupDateKey) AS MinPickupDateKey, MAX(PickupDateKey) AS MaxPickupDateKey
FROM dbo.Fact_YellowGreen_Trips
WHERE SourceKey = N'yellow_tripdata_2013-01.csv'
GROUP BY SourceDataset, SourceKey;

SELECT DatasetCode, SourceKey, ExpectedRows, RowsLoaded, RowLimit, LoadStatus
FROM NYCTaxi_Staging.etl.ExtractFileLog
WHERE SourceKey LIKE '%2013-01%';

SELECT TOP (10) RunId, StartMonth, EndMonth, RowLimit, Status, StartedAt, CompletedAt, ErrorMessage
FROM etl.PipelineRun WHERE StartMonth = '2013-01' ORDER BY StartedAt DESC;

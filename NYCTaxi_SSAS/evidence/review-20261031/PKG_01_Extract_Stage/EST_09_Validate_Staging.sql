SET NOCOUNT ON;
DECLARE @StartMonth DATE = CONVERT(DATE, ? + '-01', 23),
        @EndMonth DATE = CONVERT(DATE, ? + '-01', 23), @RowLimit INT = ?;
IF @StartMonth > @EndMonth OR @RowLimit < 0 THROW 51010, 'Invalid extraction range.', 1;
DECLARE @Month DATE = @StartMonth;
DECLARE @Expected TABLE (DatasetCode VARCHAR(20), SourceKey NVARCHAR(260), RowLimit INT);
WHILE @Month <= @EndMonth
BEGIN
    INSERT @Expected (DatasetCode, SourceKey, RowLimit)
    SELECT DatasetCode, DatasetCode + '_tripdata_' + CONVERT(CHAR(7), @Month, 126) + '.csv', @RowLimit
    FROM (VALUES ('yellow',CONVERT(date,'20090101')), ('green',CONVERT(date,'20130801')),
        ('fhv',CONVERT(date,'20150101')), ('fhvhv',CONVERT(date,'20190201'))) AS D(DatasetCode,FirstMonth)
    WHERE @Month >= D.FirstMonth;
    IF @Month = @EndMonth BREAK;
    SET @Month = DATEADD(MONTH, 1, @Month);
END;
INSERT @Expected VALUES ('lookup', 'taxi_zone_lookup.csv', 0);
IF EXISTS (
    SELECT 1 FROM @Expected AS E LEFT JOIN etl.ExtractFileLog AS L
        ON L.DatasetCode = E.DatasetCode AND L.SourceKey = E.SourceKey
    WHERE L.SourceKey IS NULL OR L.LoadStatus <> 'SUCCEEDED'
        OR L.RowLimit <> E.RowLimit OR L.RowsLoaded IS NULL OR L.RowsLoaded <> L.ExpectedRows)
    THROW 51007, 'File load coverage is incomplete. Check etl.ExtractFileLog.', 1;

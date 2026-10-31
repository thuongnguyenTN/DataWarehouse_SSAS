SET NOCOUNT ON;
DECLARE @ZoneText NVARCHAR(MAX),@ZoneHash CHAR(64);
SELECT @ZoneText=CONVERT(NVARCHAR(MAX),
    (SELECT LocationID,Borough,Zone,ServiceZone
     FROM clean.TaxiZone WITH(HOLDLOCK)
     ORDER BY LocationID FOR XML RAW('z'),TYPE));
SET @ZoneHash=CONVERT(CHAR(64),HASHBYTES('SHA2_256',@ZoneText),2);

/* Doc log nho de kiem tra coverage; khong UPDATE lai toan bo clean. */
IF NOT EXISTS(SELECT 1 FROM etl.ExtractFileLog
    WHERE DatasetCode IN ('yellow','green','fhv','fhvhv') AND LoadStatus='SUCCEEDED')
    THROW 51230, 'Chua co tep chuyen di Extract thanh cong.', 1;

IF EXISTS(SELECT 1 FROM etl.ExtractFileLog AS e
    LEFT JOIN etl.TransformFileLog AS t ON t.DatasetCode=e.DatasetCode AND t.SourceKey=e.SourceKey
    WHERE e.DatasetCode IN ('yellow','green','fhv','fhvhv') AND e.LoadStatus='SUCCEEDED'
        AND (t.SourceKey IS NULL OR t.FileHash<>e.FileHash
            OR t.SourceRows<>e.ExpectedRows OR t.CleanRows<>e.ExpectedRows
            OR t.RuleVersion<>'INCR_20261019_1|hours=48' OR t.ZoneHash<>@ZoneHash
            OR t.CleanRows<>t.ValidRows+t.RejectedRows))
    THROW 51231, 'Con tep chua Transform dung phien ban hien tai. Kiem tra log.', 1;

SELECT t.DatasetCode,COUNT_BIG(*) AS CompletedFiles,
    SUM(t.SourceRows) AS SourceRows,SUM(t.CleanRows) AS CleanRows,
    SUM(t.ValidRows) AS ValidRows,SUM(t.RejectedRows) AS RejectedRows,
    SUM(t.WarningRows) AS WarningRows
FROM etl.TransformFileLog AS t
INNER JOIN etl.ExtractFileLog AS e ON e.DatasetCode=t.DatasetCode AND e.SourceKey=t.SourceKey
WHERE e.LoadStatus='SUCCEEDED' AND t.FileHash=e.FileHash
GROUP BY t.DatasetCode ORDER BY t.DatasetCode;

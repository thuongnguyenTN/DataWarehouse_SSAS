SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @FileHash CHAR(64), @ExpectedRows BIGINT, @CleanRows BIGINT,
        @ZoneText NVARCHAR(MAX), @ZoneHash CHAR(64), @Processed INT=0;
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @FileHash=FileHash, @ExpectedRows=ExpectedRows
    FROM etl.ExtractFileLog WITH(UPDLOCK,HOLDLOCK)
    WHERE DatasetCode='lookup' AND SourceKey='taxi_zone_lookup.csv'
        AND LoadStatus='SUCCEEDED' AND RowsLoaded=ExpectedRows;
    IF @ExpectedRows IS NULL OR @ExpectedRows=0
        THROW 51210, 'Extract lookup chua hoan tat.', 1;

    SELECT @CleanRows=COUNT_BIG(*) FROM clean.TaxiZone WITH(HOLDLOCK);
SELECT @ZoneText=CONVERT(NVARCHAR(MAX),
    (SELECT LocationID,Borough,Zone,ServiceZone
     FROM clean.TaxiZone WITH(HOLDLOCK)
     ORDER BY LocationID FOR XML RAW('z'),TYPE));
SET @ZoneHash=CONVERT(CHAR(64),HASHBYTES('SHA2_256',@ZoneText),2);

    IF NOT EXISTS(SELECT 1 FROM etl.TransformFileLog WITH(UPDLOCK,HOLDLOCK)
        WHERE DatasetCode='lookup' AND SourceKey='taxi_zone_lookup.csv'
            AND FileHash=@FileHash AND SourceRows=@ExpectedRows
            AND CleanRows=@CleanRows AND CleanRows=@ExpectedRows
            AND RuleVersion='INCR_ZONE_20261019_1' AND ZoneHash=@ZoneHash)
    BEGIN
        /* Chi doc staging lookup neu can xu ly lai. */
        IF (SELECT COUNT_BIG(*) FROM stg.TaxiZone WITH(HOLDLOCK))<>@ExpectedRows
            OR EXISTS(SELECT 1 FROM stg.TaxiZone WITH(HOLDLOCK)
                WHERE ETLSourceKey IS NULL OR ETLSourceKey<>'taxi_zone_lookup.csv'
                    OR ETLFileHash IS NULL OR ETLFileHash<>@FileHash)
            THROW 51211, 'Staging lookup khong khop log Extract. Chay lai PKG_01.', 1;

DELETE FROM clean.TaxiZone;

;WITH Z AS
(
    SELECT
        TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(LocationID)), '')) AS LocationID,
        NULLIF(LTRIM(RTRIM(Borough)), '') AS Borough,
        NULLIF(LTRIM(RTRIM(Zone)), '') AS Zone,
        NULLIF(LTRIM(RTRIM(REPLACE(service_zone, CHAR(13), ''))), '') AS ServiceZone
    FROM stg.TaxiZone
), R AS
(
    SELECT *, ROW_NUMBER() OVER
        (PARTITION BY LocationID ORDER BY Borough, Zone, ServiceZone) AS RowNum
    FROM Z
    WHERE LocationID > 0 AND Zone IS NOT NULL
)
INSERT INTO clean.TaxiZone(LocationID, Borough, Zone, ServiceZone)
SELECT LocationID, Borough, Zone, ServiceZone
FROM R
WHERE RowNum = 1;

IF NOT EXISTS(SELECT 1 FROM clean.TaxiZone)
    THROW 51004, 'Khong co TaxiZone hop le; rollback lookup.', 1;



        SELECT @CleanRows=COUNT_BIG(*) FROM clean.TaxiZone;
        IF @CleanRows<>@ExpectedRows
            THROW 51212, 'Lookup co ID loi/trung. Giu lookup cu va kiem tra staging.', 1;
SELECT @ZoneText=CONVERT(NVARCHAR(MAX),
    (SELECT LocationID,Borough,Zone,ServiceZone
     FROM clean.TaxiZone WITH(HOLDLOCK)
     ORDER BY LocationID FOR XML RAW('z'),TYPE));
SET @ZoneHash=CONVERT(CHAR(64),HASHBYTES('SHA2_256',@ZoneText),2);
        DELETE FROM etl.TransformFileLog
        WHERE DatasetCode='lookup' AND SourceKey='taxi_zone_lookup.csv';
        INSERT etl.TransformFileLog
            (DatasetCode,SourceKey,FileHash,RuleVersion,ZoneHash,SourceRows,
             CleanRows,ValidRows,RejectedRows,WarningRows,CompletedAt)
        VALUES('lookup','taxi_zone_lookup.csv',@FileHash,'INCR_ZONE_20261019_1',@ZoneHash,
            @ExpectedRows,@CleanRows,@CleanRows,0,0,SYSDATETIME());
        SET @Processed=1;
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
SELECT 'lookup' AS DatasetCode,@Processed AS ProcessedFiles,1-@Processed AS SkippedFiles;

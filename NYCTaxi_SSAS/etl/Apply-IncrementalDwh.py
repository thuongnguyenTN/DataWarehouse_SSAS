"""Patch the current DWH package in place; preserve all SSIS metadata and UI layout."""
from pathlib import Path
import re
from lxml import etree as E

ROOT=Path(__file__).parent
D='{www.microsoft.com/SqlServer/Dts}'
S='{www.microsoft.com/sqlserver/dts/tasks/sqltask}'
VERSION='FILE_V1_20261031'
MAPS="""
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
"""
PENDING=f"""
DROP TABLE IF EXISTS #DwhTodo;
SELECT S.* INTO #DwhTodo FROM etl.DwhSourceState S
LEFT JOIN etl.DwhFileLog L ON L.DatasetCode=S.DatasetCode AND L.SourceKey=S.SourceKey
WHERE L.SourceKey IS NULL OR L.Status<>'SUCCEEDED' OR L.ForceReload=1
 OR L.SourceVersion<>S.SourceVersion OR L.LoaderVersion<>'{VERSION}'
 OR (L.UnknownMask&1=1 AND L.LocationMapHash<>@LocationMapHash)
 OR (L.UnknownMask&2=2 AND L.BaseMapHash<>@BaseMapHash)
 OR (L.UnknownMask&4=4 AND L.OtherMapHash<>@OtherMapHash);
CREATE UNIQUE CLUSTERED INDEX IX_DwhTodo ON #DwhTodo(DatasetCode,SourceKey);
"""

def dimensions(sql):
    sql=sql.replace(' BEGIN TRAN;', ' BEGIN TRAN;\n'+MAPS+PENDING+"""
 DROP TABLE IF EXISTS #DeltaTrip;
 SELECT C.* INTO #DeltaTrip
 FROM #DwhTodo T JOIN NYCTaxi_Staging.clean.ValidTrip C
 ON C.TaxiType=UPPER(T.DatasetCode) AND C.ETLSourceKey=T.SourceKey;
""",1)
    # Replace references only after creating the delta input.
    marker=sql.index(' -- All physical')
    sql=sql[:marker]+sql[marker:].replace('NYCTaxi_Staging.clean.ValidTrip','#DeltaTrip')
    sql=sql.replace(' COMMIT TRAN;',"""
 SELECT (SELECT COUNT(*) FROM #DwhTodo) AS PendingFiles,
        (SELECT COUNT_BIG(*) FROM #DeltaTrip) AS DimensionInputRows;
 DROP TABLE #DeltaTrip; DROP TABLE #DwhTodo;
 COMMIT TRAN;""",1)
    return sql

def fact(sql):
    table=re.search(r'INSERT INTO dbo\.(Fact_\w+)',sql)[1]
    cte=sql[sql.index(';WITH SourceRows AS'):sql.index('    SELECT * INTO #Desired FROM FactValues;')]
    cte=cte.replace('FROM NYCTaxi_Staging.clean.ValidTrip C',
        'FROM NYCTaxi_Staging.clean.ValidTrip C\n  INNER JOIN #CurrentFile F ON C.TaxiType=UPPER(F.DatasetCode) AND C.ETLSourceKey=F.SourceKey')
    cte=cte.replace('PARTITION BY S.PayloadHash','PARTITION BY S.TaxiType,S.ETLSourceKey,S.PayloadHash')
    cte=cte.replace("CONCAT(CONVERT(varchar(64),R.PayloadHash,2),':',R.DuplicateOrdinal)",
        "CONCAT(R.TaxiType,'|',R.ETLSourceKey,'|',CONVERT(varchar(64),R.PayloadHash,2),':',R.DuplicateOrdinal)")
    loc='(C.PULocationID IS NOT NULL AND COALESCE(PickupZone.LocationKey,0)=0) OR (C.DOLocationID IS NOT NULL AND COALESCE(DropoffZone.LocationKey,0)=0)'
    base=[];other=[]
    for alias,source,key in [('DispatchBase','DispatchingBaseNum','BaseKey'),('OriginBase','OriginatingBaseNum','BaseKey'),('AffiliatedBase','AffiliatedBaseNum','BaseKey')]:
        if re.search(r'LEFT JOIN dbo\.\w+ AS '+alias+r'\b',cte):base.append(f'(C.{source} IS NOT NULL AND COALESCE({alias}.{key},0)=0)')
    for alias,source,key in [('Vendor','VendorID','VendorKey'),('RateCode','RateCodeID','RateCodeKey'),('Payment','PaymentTypeID','PaymentTypeKey'),('TripType','TripTypeID','TripTypeKey'),('Provider','HVFHSLicenseNum','HVFHSProviderKey')]:
        if re.search(r'LEFT JOIN dbo\.\w+ AS '+alias+r'\b',cte):other.append(f'(C.{source} IS NOT NULL AND COALESCE({alias}.{key},0)=0)')
    mask=f'CASE WHEN {loc} THEN 1 ELSE 0 END'
    if base:mask+=' + CASE WHEN '+' OR '.join(base)+' THEN 2 ELSE 0 END'
    if other:mask+=' + CASE WHEN '+' OR '.join(other)+' THEN 4 ELSE 0 END'
    cte=cte.replace('C.ETLSourceKey AS SourceKey','C.ETLSourceKey AS SourceKey,\n    '+mask+' AS UnresolvedMask')
    # Reuse the tested mapping and insert column list, not the old global reconciliation.
    oldinsert=sql[sql.index('    INSERT INTO dbo.'+table):sql.index('    DECLARE @InsertedRows')]
    cols=[x.strip() for x in re.search(r'INSERT INTO dbo\.\w+\s*\(([^)]+)\)',oldinsert)[1].split(',')]
    updates=','.join(f'{c}=V.{c}' for c in cols if c!='RecordHash')
    oldvalues=','.join('F.'+c for c in cols if c!='RecordHash')
    newvalues=','.join('V.'+c for c in cols if c!='RecordHash')
    datasets={'Fact_YellowGreen_Trips':"'yellow','green'",'Fact_FHV_Trips':"'fhv'",'Fact_HVFHV_Trips':"'fhvhv'"}[table]
    return f"""SET NOCOUNT ON; SET XACT_ABORT ON;
{MAPS}
{PENDING}
DELETE FROM #DwhTodo WHERE DatasetCode NOT IN ({datasets});
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
{cte}
  SELECT * INTO #Desired FROM FactValues;
  CREATE UNIQUE CLUSTERED INDEX IX_Desired_Hash ON #Desired(RecordHash);
  IF (SELECT COUNT_BIG(*) FROM #Desired)<>@Expected
   THROW 55941,'File clean rows disagree with Transform checkpoint.',1;
  IF EXISTS(SELECT 1 FROM #Desired WHERE ServiceTypeKey=0)
   THROW 55942,'Unknown ServiceTypeKey in changed file.',1;
  INSERT etl.FactChangeAudit(TableName,RowJson)
   SELECT N'{table}',(SELECT F.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
   FROM dbo.{table} F
   WHERE F.SourceDataset=@Dataset AND F.SourceKey=@Source
     AND NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash);
  DELETE F FROM dbo.{table} F
   WHERE F.SourceDataset=@Dataset AND F.SourceKey=@Source
     AND NOT EXISTS(SELECT 1 FROM #Desired V WHERE V.RecordHash=F.RecordHash);
  SET @Deleted=@@ROWCOUNT;
  UPDATE F SET {updates}
   FROM dbo.{table} F JOIN #Desired V ON V.RecordHash=F.RecordHash
   WHERE F.SourceDataset=@Dataset AND F.SourceKey=@Source
     AND EXISTS(SELECT {oldvalues} EXCEPT SELECT {newvalues});
  SET @Updated=@@ROWCOUNT;
{oldinsert}
  SET @Inserted=@@ROWCOUNT;
  IF TRY_CONVERT(int,SESSION_CONTEXT(N'NYCTaxiFailAfterFactWrite'))=1
   THROW 55949,'Injected failure after Fact write, before checkpoint.',1;
  SELECT @FactRows=COUNT_BIG(*) FROM dbo.{table} WHERE SourceDataset=@Dataset AND SourceKey=@Source;
  IF @FactRows<>@Expected THROW 55943,'File Fact reconciliation failed.',1;
  SELECT @Unknown=COALESCE(MAX(UnresolvedMask&1),0)+COALESCE(MAX(UnresolvedMask&2),0)+COALESCE(MAX(UnresolvedMask&4),0) FROM #Desired;
  DELETE etl.DwhFileLog WHERE DatasetCode=@Dataset AND SourceKey=@Source;
  INSERT etl.DwhFileLog(DatasetCode,SourceKey,SourceVersion,LoaderVersion,Status,ForceReload,
   ValidRows,FactRows,InsertedRows,UpdatedRows,DeletedRows,UnknownMask,LocationMapHash,BaseMapHash,OtherMapHash,CompletedAt)
  VALUES(@Dataset,@Source,@Token,'{VERSION}','SUCCEEDED',0,@Expected,@FactRows,@Inserted,@Updated,@Deleted,@Unknown,
   @LocationMapHash,@BaseMapHash,@OtherMapHash,SYSUTCDATETIME());
  INSERT etl.LoadStepLog(StepName,InsertedRows) VALUES(N'{table}',@Inserted);
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
"""

VALIDATE=f"""SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM NYCTaxi_Staging.etl.ExtractFileLog E
 LEFT JOIN etl.DwhSourceState S ON S.DatasetCode=E.DatasetCode AND S.SourceKey=E.SourceKey
 WHERE E.DatasetCode IN('yellow','green','fhv','fhvhv') AND E.LoadStatus='SUCCEEDED' AND S.SourceKey IS NULL)
 THROW 55944,'Extract/Transform coverage is incomplete; DWH checkpoint cannot be accepted.',1;
{MAPS}
{PENDING}
IF EXISTS(SELECT 1 FROM #DwhTodo) THROW 55945,'DWH file checkpoints are incomplete.',1;
DROP TABLE #DwhTodo;
UPDATE dbo.Dim_LoadBatch SET BatchStatus='SUCCEEDED',LoadedAt=SYSDATETIME() WHERE BatchStatus='READY' AND BatchID LIKE 'CLEAN-%';
SELECT COUNT(*) AS CompletedFiles, SUM(FactRows) AS CheckpointFactRows FROM etl.DwhFileLog WHERE Status='SUCCEEDED';
"""

def apply(path):
    tree=E.parse(str(path));tasks=tree.getroot().find(D+'Executables')
    first=tasks[0].find('.//'+S+'SqlTaskData')
    if VERSION in first.get(S+'SqlStatementSource'):
        sql=first.get(S+'SqlStatementSource')
        sql=sql.replace("WHERE E.LoadStatus=''SUCCEEDED'' AND E.RowsLoaded=E.ExpectedRows",
            "WHERE E.DatasetCode IN(''yellow'',''green'',''fhv'',''fhvhv'') AND E.LoadStatus=''SUCCEEDED'' AND E.RowsLoaded=E.ExpectedRows")
        first.set(S+'SqlStatementSource',sql)
        tree.write(str(path),encoding='utf-8',xml_declaration=True)
        from runpy import run_path
        run_path(str(ROOT/'hardening/patch_business.py'))['apply'](path)
        return
    for task in tasks:
        node=task.find('.//'+S+'SqlTaskData');sql=node.get(S+'SqlStatementSource');name=task.get(D+'ObjectName')
        if 'Precheck' in name:
            # Null record/hash migration checks use source index; no full payload work per run.
            sql=re.sub(r'IF EXISTS\(SELECT 1 FROM dbo.Fact_YellowGreen_Trips WHERE RecordHash IS NULL\)[\s\S]*?THROW 55007[^;]+;', '',sql)
            sql+='\n-- '+VERSION+'\n'+(ROOT/'incremental/002-file-checkpoints.sql').read_text()
            for table in ('Fact_YellowGreen_Trips','Fact_FHV_Trips','Fact_HVFHV_Trips'):
                sql+=f"\nIF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.{table}') AND name='IX_DwhFile_Source') CREATE INDEX IX_DwhFile_Source ON dbo.{table}(SourceDataset,SourceKey) INCLUDE(RecordHash);\n"
                sql+=f"IF EXISTS(SELECT 1 FROM dbo.{table} WHERE SourceKey IS NULL OR SourceDataset IS NULL) THROW 55946,'Legacy facts have no source. Migrate lineage before incremental loading.',1;\n"
        elif 'Dimensions' in name:sql=dimensions(sql)
        elif 'Load_Fact' in name:sql=fact(sql)
        elif 'Validate' in name:sql=VALIDATE
        node.set(S+'SqlStatementSource',sql)
    tree.write(str(path),encoding='utf-8',xml_declaration=True)
    from runpy import run_path
    run_path(str(ROOT/'hardening/patch_business.py'))['apply'](path)

if __name__=='__main__':
    import sys
    apply(Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'packages/PKG_03_Load_DWH.dtsx')

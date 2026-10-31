CREATE   VIEW etl.DwhSourceState AS
 SELECT T.DatasetCode,T.SourceKey,T.FileHash,T.ValidRows,T.SourceRows,T.CompletedAt,
 CONVERT(char(64),HASHBYTES('SHA2_256',CONCAT(T.FileHash,'|',T.RuleVersion,'|',T.ZoneHash,
 '|',T.SourceRows,'|',T.ValidRows,'|',T.RejectedRows,'|',CONVERT(varchar(33),T.CompletedAt,126))),2) AS SourceVersion
 FROM NYCTaxi_Staging.etl.TransformFileLog T
 JOIN NYCTaxi_Staging.etl.ExtractFileLog E ON E.DatasetCode=T.DatasetCode AND E.SourceKey=T.SourceKey
 WHERE E.LoadStatus='SUCCEEDED' AND E.RowsLoaded=E.ExpectedRows
 AND E.FileHash=T.FileHash AND E.ExpectedRows=T.SourceRows AND T.CleanRows=T.SourceRows
 AND T.ValidRows+T.RejectedRows=T.CleanRows;

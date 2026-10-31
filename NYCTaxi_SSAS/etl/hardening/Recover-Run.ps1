param([Parameter(Mandatory=$true)][guid]$RunId,[switch]$Execute)
$ErrorActionPreference='Stop'
$c=New-Object Data.SqlClient.SqlConnection 'Server=THUONGNGUYEN\MSSQLSV;Database=NYCTaxi_DWH;Integrated Security=True;Connect Timeout=10'
try{
 $c.Open();$q=$c.CreateCommand();$null=$q.Parameters.AddWithValue('@r',$RunId)
 if(-not $Execute){$q.CommandText='SELECT * FROM etl.PipelineRun WHERE RunId=@r';$a=New-Object Data.SqlClient.SqlDataAdapter $q;$t=New-Object Data.DataTable;$null=$a.Fill($t);$t|Format-List;return}
 $q.CommandText=@'
SET XACT_ABORT ON; BEGIN TRAN;
DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource=N'NYCTaxi-Full-Pipeline',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @lock<0 BEGIN ROLLBACK; THROW 55990,'ETL active; recovery refused.',1; END;
IF NOT EXISTS(SELECT 1 FROM etl.PipelineRun WHERE RunId=@r AND Status='RUNNING') BEGIN ROLLBACK; THROW 55991,'Run is not RUNNING; recovery refused.',1; END;
UPDATE etl.PipelineStep SET Status='FAILED',CompletedAt=SYSUTCDATETIME(),ErrorMessage=N'Interrupted run closed by guarded recovery.' WHERE RunId=@r AND Status='RUNNING';
UPDATE etl.PipelineRun SET Status='FAILED',CompletedAt=SYSUTCDATETIME(),ErrorMessage=N'Interrupted run closed by guarded recovery.' WHERE RunId=@r AND Status='RUNNING';
COMMIT;
'@
 $null=$q.ExecuteNonQuery();'Run marked FAILED; successful checkpoints preserved.'
}finally{$c.Dispose()}

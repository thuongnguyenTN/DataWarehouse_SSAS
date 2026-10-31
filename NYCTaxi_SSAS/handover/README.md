# Bàn giao NYC Taxi sang máy khác (không kèm tải dữ liệu)

## 1. Những gì phải đưa lên Git

Repo SSIS: toàn bộ project thực `NYCTaxi_ETL.dtproj`, Project.params, *.dtsx, *.conmgr; không chỉ các file package. Repo SSAS: solution/project, *.database, *.ds, *.dsv, *.dim, sáu *.cube, *.partitions.

Ngoài hai project, **bắt buộc** giữ `etl/`, `scripts/`, `deployment/`, `powerbi/`, `handover/` của repo hiện tại. Master gọi PowerShell/Python bên ngoài project; chỉ clone SSIS/SSAS sẽ không chạy được. Giữ ProcessLifetime.cs, Pipeline.Progress.ps1, Invoke-SsisStage.ps1, Invoke-NYCTaxiPipeline.ps1 và etl/python.

Không commit raw, csv, quarantine, logs, alerts, backup, .vs, bin, obj, .ispac, mật khẩu hoặc tên tài khoản được cấp quyền riêng. Không commit database IncTest. Model Power BI PBIP/PBIR và SemanticModel/modelReference.json cần có; file exe có thể build từ C#.

## 2. Trước khi rời máy nguồn: xuất SQL bằng SSMS

SSIS/SSAS không chứa đầy đủ DDL và seed của SQL Server. Không dùng file D:\Kho_Du_lieu\04_create_nyctaxi_dwh.sql làm installer: file hiện tại chỉ là truy vấn đối soát.

Trong SSMS, với từng database NYCTaxi_Staging và NYCTaxi_DWH: Tasks → Generate Scripts → chọn tất cả đối tượng cần thiết, bỏ sysdiagrams → Advanced:

- Types of data to script: **Schema only**.
- Script Indexes=True; Primary Keys=True; Foreign Keys=True; Unique Keys=True; Check Constraints=True; Defaults=True.
- Script Triggers=True nếu có; giữ schema, views, stored procedures và functions.
- Script Database Create=False để không mang đường dẫn MDF/LDF máy nguồn.
- Chọn server version tương ứng máy đích; UTF-8/Unicode.
- Lưu `handover/sql/01-Staging-Schema.sql`, `02-DWH-Schema.sql` rồi commit.

Xuất riêng các bảng `dbo.Dim_*` của DWH thành `03-Dimension-Seeds.sql`, Advanced → **Data only**. Đây là danh mục tham chiếu, có Date/Time/code/Unknown cần để lookup. Không chọn fact, clean, staging hoặc etl log/checkpoint. Cách này có thể mang danh mục Location/Base/LoadBatch đã biết từ máy nguồn, nhưng không mang chuyến đi hoặc trạng thái run. Nếu cần bộ seed sạch tuyệt đối, chỉ giữ key=0 của Location/Base/LoadBatch; không xóa Unknown.

Chưa có ba file SQL này trong bộ bàn giao hiện tại. Phải tạo và kiểm thử chúng trước khi tuyên bố clone là dựng được toàn bộ. Không chuyển database log đã có SUCCEEDED sang máy trắng.

## 3. Phần mềm máy đích

- Windows x64; SQL Server 2022 Developer cho đồ án (không dùng Developer cho production thương mại).
- Database Engine và **Analysis Services Multidimensional and Data Mining**. Không chọn Tabular. SSMS chỉ là công cụ quản trị, cài SSMS không tự tạo hai dịch vụ này.
- Khuyến nghị đặt instance SQL và SSAS cùng tên, ví dụ MAYMOI\MSSQLSV, vì bộ cấu hình tự động bên dưới dùng chung endpoint. Hai dịch vụ là hai kết nối khác nhau trong SSMS.
- Visual Studio 2022 với extension Integration Services Projects và Analysis Services Projects. TargetServerVersion của SSIS phải tương ứng SQL Server đích.
- OLE DB provider mà connection manager yêu cầu: bản hiện tại SSIS dùng SQLOLEDB.1, SSAS dùng MSOLEDBSQL. Kiểm tra provider trước khi Test Connection; nếu đổi provider phải cập nhật chuỗi kết nối cả project và artifact deployment.
- Python 3.10 x64; Power BI Desktop hỗ trợ PBIP/PBIR; Git.
- AMO/ADOMD.NET tương thích, các DLL theo machine.json phải thực sự tồn tại. Bộ script hiện dùng AMO đi kèm extension SSAS của VS và ADOMD.NET 160.

## 4. Thư mục và clone

Ví dụ dùng một ổ C, không bắt buộc có D/E như máy cũ. Chạy PowerShell:

```powershell
New-Item -ItemType Directory C:\NYCTaxi -Force
git clone <URL_REPO_SSAS_VA_RUNTIME> C:\NYCTaxi\NYCTaxi_SSAS
git clone <URL_REPO_SSIS> C:\NYCTaxi\NYCTaxi_ETL
Set-Location C:\NYCTaxi\NYCTaxi_SSAS
Copy-Item handover\machine.example.json handover\machine.json
notepad handover\machine.json
```

Sửa Server, RepoRoot, SsisRoot, DataRoot, PythonExe và đường dẫn DLL theo máy. Không commit machine.json của từng thành viên. Không dùng nguyên tên THUONGNGUYEN trên máy mới.

```powershell
# Xem trước danh sách file cần đổi, chưa ghi
powershell -NoProfile -ExecutionPolicy Bypass -File handover\Configure-Machine.ps1 -Config handover\machine.json
# Áp dụng trên bản clone dành cho máy mới, có backup file đổi
powershell -NoProfile -ExecutionPolicy Bypass -File handover\Configure-Machine.ps1 -Config handover\machine.json -Apply
$m = Get-Content handover\machine.json -Raw | ConvertFrom-Json
& $m.PythonExe -m pip install -r handover\requirements.txt
& $m.PythonExe -c "import pyarrow,lxml,jsonschema; print('Python OK')"
```

Script cấu hình thay các endpoint/đường dẫn cố định đã biết trong file runtime/project/deployment và copy Python vào DataRoot\script. Dùng dry-run trước và xem git diff sau khi Apply; đây là thay thế cấu hình cho bản clone, chưa phải framework cấu hình tập trung. Nếu SQL/SSAS khác endpoint, sửa riêng SqlServer/SsasServer trong runner, SSAS data source, scripts SSAS và modelReference Power BI sau bước này.

## 5. Tạo SQL database và cấu trúc trong SSMS

Kết nối **Database Engine** bằng tài khoản có quyền tạo database. Chạy trên máy trắng:

```sql
USE master;
IF DB_ID(N'NYCTaxi_Staging') IS NOT NULL
 OR DB_ID(N'NYCTaxi_DWH') IS NOT NULL
    THROW 55990, N'Database đã tồn tại: dừng để kiểm tra, không ghi đè.', 1;
CREATE DATABASE NYCTaxi_Staging;
GO
CREATE DATABASE NYCTaxi_DWH;
GO
```

Đảm bảo hai database có cùng collation phù hợp bộ schema nguồn để tránh lỗi cross-database JOIN. Không chép đường dẫn MDF/LDF của máy cũ. Sau đó mở và chạy đúng thứ tự:

1. `01-Staging-Schema.sql` trong NYCTaxi_Staging.
2. `02-DWH-Schema.sql` trong NYCTaxi_DWH. View DwhSourceState tham chiếu Staging nên Staging phải có trước.
3. `03-Dimension-Seeds.sql` trong NYCTaxi_DWH.
4. `etl/001-pipeline-control.sql` trong NYCTaxi_DWH (bổ sung nếu chưa có).

Nếu dùng sqlcmd đã cài:

```powershell
sqlcmd -S $m.Server -E -d NYCTaxi_Staging -b -i handover\sql\01-Staging-Schema.sql
if ($LASTEXITCODE) { throw 'Staging schema failed' }
sqlcmd -S $m.Server -E -d NYCTaxi_DWH -b -i handover\sql\02-DWH-Schema.sql
if ($LASTEXITCODE) { throw 'DWH schema failed' }
sqlcmd -S $m.Server -E -d NYCTaxi_DWH -b -i handover\sql\03-Dimension-Seeds.sql
if ($LASTEXITCODE) { throw 'Seed failed' }
sqlcmd -S $m.Server -E -d NYCTaxi_DWH -b -i etl\001-pipeline-control.sql
```

Không chạy lại Install-Pipeline.ps1/Reset-DemoData.ps1 trên máy đã có dữ liệu chỉ để cấu hình. Installer cũ có baseline DWH và backup; không phải trình cài đặt máy trắng tổng quát.

## 6. Quyền tài khoản

Trong SQL Server Configuration Manager/Services xác định tài khoản thực của dịch vụ SSAS. Ví dụ instance MSSQLSV có thể dùng `NT SERVICE\MSOLAP$MSSQLSV`; phải kiểm tra tên thật, không đoán. SSAS data source đang dùng ImpersonateServiceAccount, vì vậy cấp SELECT DWH cho tài khoản dịch vụ đó, không chỉ cho tài khoản đăng nhập SSMS:

```sql
USE master;
-- Thay bằng tài khoản dịch vụ SSAS thực tế
CREATE LOGIN [NT SERVICE\MSOLAP$MSSQLSV] FROM WINDOWS;
GO
USE NYCTaxi_DWH;
CREATE USER [NT SERVICE\MSOLAP$MSSQLSV]
    FOR LOGIN [NT SERVICE\MSOLAP$MSSQLSV];
ALTER ROLE db_datareader ADD MEMBER [NT SERVICE\MSOLAP$MSSQLSV];
GO
```

Nếu login/user đã có, không CREATE lần nữa. SQL và SSAS khác máy phải dùng danh tính domain phù hợp, không dùng virtual service account cục bộ của máy khác.

Tài khoản chạy ETL cần đọc/ghi DWH+Staging, thực thi stored procedure và quyền DDL vì package hiện có bước đảm bảo schema/index. Với máy demo riêng, có thể cấp db_owner trên đúng hai database; không mặc định cấp sysadmin toàn server. Trong SSAS cấp quyền process cho tài khoản ETL; tài khoản Power BI cấp Read qua database role. Tài khoản deploy cần quyền quản trị SSAS phù hợp. Các quyền này là cấu hình trên server đích, Git không mang theo Windows principal.

## 7. Cấu hình và deploy SSAS

Mở SSAS project trong Visual Studio: Deployment.Server=server đích; Deployment.Database=NYCTaxi_SSAS. Kiểm tra DS_NYCTaxi_DWH: đúng SQL Server, database và provider; Impersonation=service account như bước trên. Chọn Build rồi Deploy metadata lên database mới. Giữ sáu cube; không gộp thành một cube.

Cách dùng script thay thế VS sau khi đã kiểm tra file cấu hình:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build-Xmla.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Ssas.ps1 -Action Deploy
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Ssas.ps1 -Action Status
```

Deploy chỉ dùng khi database SSAS chưa tồn tại. Không dùng Update/AllowOverwrite để vượt lỗi tên database. Chưa có dữ liệu thì không đòi cube có số chuyến hoặc Power BI render dữ liệu; Process thực hiện sau khi ETL có nguồn.

## 8. Cấu hình và kiểm tra SSIS

Mở project SSIS. Test Connection hai connection manager; kiểm tra đúng database. Mở Master → Parameters: pRunnerPath trỏ tới RepoRoot\etl\Invoke-NYCTaxiPipeline.ps1, pControllerPath trỏ Invoke-SsisStage.ps1. pResumeRunId trống, pStartStage=Extract cho lượt mới. Không giữ RunId của máy cũ.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File etl\monitor\Build-Monitor.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File powerbi\Build-Launcher.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File etl\Invoke-NYCTaxiPipeline.ps1 -Stage Preflight
```

Preflight chỉ kiểm tra kết nối, đường dẫn và Python; không chứng minh đủ quyền process SSAS hoặc đầy đủ schema. Build SSIS trong VS, chưa bấm F5 trước khi kiểm tra cấu hình/phạm vi.

## 9. Dữ liệu tự chuẩn bị ngoài phạm vi bàn giao

Không có lệnh download trong hướng dẫn này. Khi đã có raw, đặt vào:

```text
DataRoot/raw/yellow/year=2021/month=01/yellow_tripdata_2021-01.parquet
DataRoot/raw/green/year=2021/month=01/green_tripdata_2021-01.parquet
DataRoot/raw/fhv/year=2021/month=01/fhv_tripdata_2021-01.parquet
DataRoot/raw/fhvhv/year=2021/month=01/fhvhv_tripdata_2021-01.parquet
DataRoot/raw/lookup/taxi_zone_lookup.csv
```

Nếu muốn chạy cả luồng chỉ dùng raw đã có, mở PowerShell ở RepoRoot và chủ động chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File etl\Invoke-NYCTaxiPipeline.ps1 -Offline -StartMonth 2021-01 -EndMonth 2021-01 -MaxRows 10000
```

Master hiện chưa có tham số Offline nên chạy Master bình thường vẫn có bước download/check source. Không gọi lệnh trên nếu mới chỉ cài phần mềm mà chưa có raw/lookup. Không thay Offline giữa hai lần resume cùng RunId vì nằm trong ConfigHash.

## 10. Power BI và lịch tự động

Kiểm tra sáu SemanticModel/modelReference.json đã đổi đúng server/database/cube và connectionType=analysisServicesDatabaseLive. Mở từng PBIP từ menu mới build, dùng Windows account có quyền Read SSAS. Power BI Live đọc cube sau Process; Refresh Power BI không tự chạy ETL. Không kèm gateway/Power BI Service trong bộ cài Desktop này.

Lịch của máy cũ không đi theo Git. Sau khi máy đích chạy thủ công thành công, chủ động đăng ký:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File etl\Register-MonthlyPipelineTask.ps1 -MaxRows 100000
```

Mở Task Scheduler → Task Scheduler Library → NYCTaxi Monthly ETL. Kiểm tra ngày 15, 10:00, action path, tài khoản và NextRunTime. Bản script có StartBoundary cố định 15/11/2026: nếu triển khai sau ngày này, sửa StartBoundary thành lần chạy đầu mong muốn trước khi đăng ký. Chạy tháng hiện tại trừ hai; tài khoản phải đăng nhập. Lịch bình thường vẫn tải/check nguồn; nếu cần chế độ offline cho lịch thì phải chỉnh wrapper trước, không mặc định lịch offline.

## 11. Lệnh nghiệm thu sau lượt nạp đầu

```sql
USE NYCTaxi_DWH;
SELECT TOP(10) * FROM etl.PipelineRun ORDER BY StartedAt DESC;
SELECT TOP(100) * FROM etl.PipelineStep ORDER BY StepId DESC;
SELECT DatasetCode,SourceKey,Status,FactRows,ErrorMessage FROM etl.DwhFileLog;
SELECT COUNT_BIG(*) AS Trips FROM dbo.Fact_YellowGreen_Trips;
SELECT COUNT_BIG(*) AS Trips FROM dbo.Fact_FHV_Trips;
SELECT COUNT_BIG(*) AS Trips FROM dbo.Fact_HVFHV_Trips;
USE NYCTaxi_Staging;
SELECT DatasetCode,SourceKey,LoadStatus,RowsLoaded FROM etl.ExtractFileLog;
SELECT * FROM etl.TransformFileLog;
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File etl\Test-DwhFullReconciliation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Verify-Results.ps1 -Scope Full
powershell -NoProfile -ExecutionPolicy Bypass -File powerbi\Get-ReportHealth.ps1
```

Kỳ vọng clean–fact không lệch, SQL–MDX đạt, sáu cube Processed và sáu kết nối Live hợp lệ. Thử rerun cùng file để xác nhận no-op, thử resume trên fixture trước khi demo. Không chạy script Test-IncrementalDwh nếu không muốn tạo hai database IncTest.

## 12. Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| Package load XML | Phiên bản extension, TargetServerVersion, typed parameter, metadata package |
| SQL login failed | Windows principal, server/instance, quyền hai database |
| SSAS process không đọc DWH | Tài khoản dịch vụ SSAS thiếu SELECT hoặc provider không có |
| DLL/AMO/ADOMD không tìm thấy | Sửa machine.json theo đường dẫn thực, chạy Configure trên clone |
| Python/module missing | Đúng PythonExe và cài requirements bằng chính executable đó |
| Invalid connection type Power BI | analysisServicesDatabaseLive, đúng cube và quyền Read |
| Unfinished run exists | Kiểm tra PipelineRun/tiến trình, resume RunId đúng; không xóa log để vượt khóa |
| Date/Time/Unknown lookup lỗi | Chưa chạy Dimension-Seeds hoặc seed/schema khác phiên bản |

## Trạng thái kiểm chứng bộ bàn giao

requirements ghim theo môi trường nguồn: Python 3.10, pyarrow 21.0.0, lxml 5.3.0, jsonschema 4.25.1. Hướng dẫn và cấu hình mẫu đã tạo, nhưng chưa thử trên máy Windows sạch. Bộ SQL schema/seed cần xuất bằng SSMS theo bước 2 và chạy thử trên database cách ly. Không gọi bộ này là installer một lệnh hoặc đã nghiệm thu khả năng chuyển máy.

Tài liệu chính thức: [Cài Analysis Services và chọn server mode](https://learn.microsoft.com/en-us/analysis-services/instances/install-windows/install-analysis-services), [SSIS extension cho VS 2022](https://learn.microsoft.com/en-us/sql/ssdt/ssis-vs2022-troubleshooting-guide), [Power BI Live với SSAS Multidimensional](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-ssas-multidimensional).

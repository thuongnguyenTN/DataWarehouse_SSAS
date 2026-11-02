# CHƯƠNG 1 TỔNG QUAN NGHIỆP VỤ VÀ DỮ LIỆU NYC TAXI
## 1.1 Giới thiệu đề tài
### 1.1.1 Bối cảnh và lý do lựa chọn đề tài
Hoạt động vận tải hành khách tại New York tạo ra nhiều bản ghi chuyến đi, phản ánh thời gian phục vụ, địa điểm đón trả, quãng đường và các khoản thu. Dữ liệu được công bố theo từng loại dịch vụ và từng tháng nên thuận lợi cho việc tải về nhưng chưa sẵn sàng để phân tích thống nhất. Tên cột, mức độ đầy đủ và ý nghĩa của một số trường khác nhau giữa taxi truyền thống, xe đặt trước qua base và xe công nghệ quy mô lớn. Nếu truy vấn trực tiếp từng file, người phân tích phải lặp lại công việc làm sạch, giải mã và tổng hợp cho mỗi câu hỏi nghiệp vụ.

Đề tài xây dựng kho dữ liệu NYC Taxi nhằm tổ chức các nguồn này thành một hệ thống có cấu trúc và có thể kiểm chứng. Kho giữ chi tiết chuyến đi để truy vết, đồng thời cung cấp các bảng tổng hợp cho phân tích tài chính, nhu cầu theo vùng và hiệu suất điều phối. SSAS tạo tầng ngữ nghĩa dùng chung; Power BI hỗ trợ người sử dụng lựa chọn thời gian, dịch vụ và địa bàn mà không phải trực tiếp viết các truy vấn xử lý dữ liệu nguồn.
### 1.1.2 Mục tiêu xây dựng hệ thống
Hệ thống hướng đến ba kết quả liên kết với nhau. Thứ nhất, dữ liệu được tiếp nhận theo hợp đồng rõ ràng, chuẩn hóa và phân loại chất lượng trước khi vào kho. Thứ hai, mô hình fact và dimension cho phép phân tích nhất quán theo thời gian, địa lý, loại dịch vụ, nhà cung cấp và base. Thứ ba, các chỉ tiêu trên báo cáo có công thức, đơn vị và phạm vi áp dụng cụ thể, có thể đối chiếu giữa SQL và SSAS.

Mục tiêu vận hành là cho phép nhận biết lần chạy nào đã thành công, file nào đã được xử lý và bước nào cần chạy lại khi có lỗi. Khả năng chạy lại phải dựa trên checkpoint và phiên bản đầu vào, tránh nạp trùng do thực hiện lại cùng một file. Tính đúng được ưu tiên trước tối ưu tốc độ: bản ghi thiếu thuộc tính có thể được giữ với Unknown, còn lỗi cấu trúc hoặc điều kiện chất lượng cốt lõi phải được phát hiện và ghi nhận.
### 1.1.3 Phạm vi dữ liệu và phạm vi thực hiện
Phạm vi nguồn gồm Yellow, Green, FHV, HVFHV và danh mục Taxi Zone. Phạm vi sản phẩm gồm lớp raw và CSV, cơ sở dữ liệu Staging, lớp clean, kho NYCTaxi_DWH, mô hình SSAS Multidimensional và các project Power BI kết nối live. Báo cáo trình bày thiết kế đã có trong mã nguồn, giải thích cách xây dựng và đối chiếu với các hồ sơ kiểm thử được lưu trong dự án.

Các kết quả định lượng sử dụng ảnh chụp bằng chứng ngày 31 tháng 10 năm 2026. Việc biên soạn không đồng nghĩa đã chạy lại ETL, xử lý lại cube hoặc kiểm tra toàn bộ giao diện Power BI. Tập demo có giới hạn số dòng theo file; vì vậy báo cáo không suy rộng các thống kê mẫu thành toàn bộ thị trường vận tải New York. Thông tin thành viên và phân công thực hiện không được đưa vào vì chưa có dữ liệu xác nhận.
## 1.2 Tổng quan nghiệp vụ vận tải hành khách tại New York
### 1.2.1 Vai trò của NYC Taxi and Limousine Commission
NYC Taxi and Limousine Commission, viết tắt TLC, là cơ quan quản lý lĩnh vực taxi và các dịch vụ vận tải hành khách thuộc phạm vi cấp phép tại New York. Trong đề tài, TLC là đầu mối công bố dữ liệu, danh mục vùng và từ điển giải thích các trường. Bản ghi được hình thành từ các hệ thống công nghệ và hồ sơ doanh nghiệp cung cấp cho TLC; việc được công bố chính thức không bảo đảm từng dòng đã hoàn toàn chính xác hoặc đầy đủ.

Từ góc độ kho dữ liệu, TLC cung cấp ngữ nghĩa chung để giải thích nguồn, còn hệ thống ETL phải thực hiện kiểm tra kỹ thuật và chất lượng dữ liệu của chính tập đã tải. Do đó, báo cáo phân biệt rõ tài liệu định nghĩa nguồn với dữ liệu đã quan sát trong kho. Mã dịch vụ, mã giấy phép và danh mục địa lý được dùng để nhận diện bối cảnh chuyến đi, không thay cho định danh hành khách hoặc tài xế.
### 1.2.2 Taxi Yellow
Yellow là nhóm taxi màu vàng thuộc hệ thống medallion, gắn với hình thức nhận khách vẫy xe và các phương thức nhận chuyến được TLC cho phép. Bản ghi Yellow chứa thời điểm bật và tắt đồng hồ, điểm đón trả, số hành khách, quãng đường, biểu giá, thanh toán và các khoản tiền. Prefix tpep trong tên trường liên quan hệ thống ghi nhận dữ liệu của taxi Yellow.

Đối tượng phân tích cơ bản là chuyến đi, không phải một lần quẹt thẻ hay một hành khách riêng lẻ. VendorID nhận diện nhà cung cấp công nghệ ghi nhận bản tin, không phải mã hãng vận tải hoặc tài xế. FareAmount là cước cơ bản; TotalAmount là khoản tổng nguồn ghi nhận. Khi phân tích tip cần nhớ dữ liệu taxi không bao gồm tip tiền mặt trong các trường được công bố tương ứng.
### 1.2.3 Taxi Green
Green còn được gọi là Boro Taxi hoặc Street Hail Livery. Dịch vụ này được tổ chức để phục vụ nhu cầu đón khách tại những khu vực được phép ngoài vùng hạn chế đối với Green. Màu xe không đủ để suy ra quyền đón ở mọi địa điểm; các giới hạn khai thác thuộc quy định TLC và không được hệ thống kho tự suy diễn từ LocationID.

Về dữ liệu, Green gần Yellow ở các nhóm thời gian, địa lý và tài chính, nhưng dùng các trường lpep và có trip_type để phân biệt cách nhận chuyến. Chính sự tương đồng này cho phép gộp Yellow và Green vào cùng transaction fact với ServiceTypeKey phân biệt nguồn. Các trường riêng của Green không được giả lập cho Yellow; trạng thái không áp dụng được giữ theo quy tắc dimension hoặc NULL của mô hình.
### 1.2.4 Dịch vụ For Hire Vehicle FHV
FHV là xe phục vụ chuyến được đặt trước và điều phối qua base, bao gồm các nhóm dịch vụ theo giấy phép như livery, black car và limousine. Base là đơn vị có vai trò tiếp nhận hoặc điều phối, không phải địa điểm đón khách và cũng không phải tài xế. Bộ dữ liệu FHV trong dự án chứa mã base, thời gian, mã vùng và cờ SR_Flag, nhưng không cung cấp nhóm cước và quãng đường đầy đủ như Yellow hoặc HVFHV.

Vì phạm vi thuộc tính khác nhau, fact FHV được thiết kế riêng để phân tích số chuyến, thời lượng, địa lý và hoạt động base. Không bổ sung cước bằng 0 để tạo một báo cáo tài chính giả cho FHV. SR_Flag có quy ước nguồn riêng; bản sửa loader chuẩn hóa giá trị 1 thành Y, 0 thành N và NULL thành U, đồng thời giữ giới hạn diễn giải của cờ theo phiên bản dữ liệu.
### 1.2.5 Dịch vụ High Volume For Hire Vehicle HVFHV
HVFHV là bộ dữ liệu chuyến của nhóm dịch vụ FHV quy mô điều phối lớn. HVFHS là loại giấy phép ở cấp nhà cung cấp, còn HVFHV là tên nhóm bản ghi chuyến thường dùng trong dự án. Nguồn này được công bố tách riêng và chi tiết hơn từ năm 2019; hợp đồng tải của chương trình bắt đầu nhận file từ tháng 2 năm 2019.

Nguồn có các mốc yêu cầu, xe đến điểm đón, pickup và dropoff; đồng thời chứa cước cơ bản, tiền tài xế, thuế phí, tip và các cờ đi chung hoặc tiếp cận xe lăn. Không phải mọi mốc thời gian đều có độ bao phủ như nhau: on_scene_datetime trong từ điển TLC gắn với xe tiếp cận, nên thiếu trường này không mặc nhiên có nghĩa xe không đến. Provider được xác định qua giấy phép HVFHS; không gọi mọi bản ghi là chuyến của một thương hiệu duy nhất.
### 1.2.6 Quy trình yêu cầu điều phối và thực hiện chuyến đi
Với chuyến có dữ liệu đặt trước, khách tạo yêu cầu, hệ thống hoặc base nhận yêu cầu và điều phối xe, xe đến điểm đón, hành khách lên xe và chuyến kết thúc tại điểm trả. Trong nguồn HVFHV, originating_base_num và dispatching_base_num có thể đại diện hai vai trò khác nhau. Các sự kiện tương ứng được giữ trên cùng dòng fact chuyến đi để tính thời lượng phục vụ mà không tạo thêm dòng cho từng trạng thái.

Đối với Yellow và Green, hệ thống chủ yếu quan sát các mốc đồng hồ và kết quả tài chính. Không có mốc request không chứng minh không có đặt xe, mà chỉ phản ánh cấu trúc nguồn đang sử dụng. Khi tổng hợp nhu cầu, một chuyến tạo một sự kiện đón và một sự kiện trả; hai sự kiện có thể thuộc vùng, phút hoặc ngày khác nhau. Đây là cơ sở để tách các phép đo TotalPickups và TotalDropoffs.
## 1.3 Giới thiệu nguồn dữ liệu
### 1.3.1 Nguồn cung cấp và phương thức công bố
Dữ liệu được lấy từ trang TLC Trip Record Data và danh mục Taxi Zone đi kèm. TLC tổ chức các liên kết tải theo tháng và loại dịch vụ. Pipeline sử dụng downloader để lựa chọn phạm vi tháng, lưu file raw và chỉ chuyển sang bước tiếp theo sau khi xác nhận đủ đầu vào cần thiết. Thông tin nguồn chính thức được liệt kê tại phần tài liệu tham khảo [1] đến [6].

Việc nhận lại file tháng cũ có thể phản ánh hiệu chỉnh nguồn. Vì vậy tên file tháng không đủ để nhận biết phiên bản; hệ thống dùng hash và metadata để phân biệt dữ liệu đã thay đổi. Tình huống không còn file ở cache hoặc nguồn không còn cung cấp một liên kết không được tự coi là yêu cầu xóa lịch sử trong DWH.
### 1.3.2 Định dạng cách tổ chức file và phạm vi thời gian
Nguồn chuyến đi ở định dạng Parquet, thuận lợi cho lưu trữ dữ liệu cột. Pipeline chuyển thành CSV UTF 8 với kết thúc dòng LF và thứ tự trường ổn định để phục vụ SSIS và SqlBulkCopy. Tệp sidecar .meta.json ghi số dòng, giới hạn dòng, danh sách cột, hash, kích thước và thông tin phiên bản chuyển đổi.

Hợp đồng chương trình quy định tháng đầu tương ứng Yellow 2009 01, Green 2013 08, FHV 2015 01 và HVFHV 2019 02. Các mốc này dùng cho việc chọn file, không có nghĩa kho hiện chứa toàn bộ lịch sử từ các thời điểm đó. MaxRows bằng 0 đọc toàn file đã chọn; MaxRows lớn hơn 0 lấy N dòng đầu của từng file. Giới hạn được áp dụng riêng từng file và không phải lấy mẫu ngẫu nhiên.
### 1.3.3 Danh mục vùng Taxi Zone
Taxi Zone Lookup ánh xạ LocationID sang Borough, Zone và service_zone. Đây là danh mục dùng chung cho PULocationID và DOLocationID ở các bộ dữ liệu chuyến đi. Trong kho, LocationID là mã nghiệp vụ nguồn còn LocationKey là khóa nội bộ dùng trong quan hệ fact dimension.

Danh mục phải được chuẩn hóa trước khi biến đổi chuyến đi. Hash danh mục tham gia phiên bản Transform vì thay đổi vùng có thể tác động đến phép kiểm tra vị trí. Các mã không tra được đi vào Unknown theo quy tắc, thay vì bị gán tùy tiện về một quận cụ thể. ZoneName là tên hiển thị; phân tích phải dựa trên khóa vùng để tránh gộp hai tên giống nhau.
### 1.3.4 Đặc điểm và sự khác biệt giữa các bộ dữ liệu
Yellow và Green có các khoản cước taxi và phương thức thanh toán; HVFHV có tài chính theo nhà cung cấp cùng thông tin chờ; FHV có cấu trúc gọn hơn. Những khác biệt này được giữ xuyên suốt đến fact và cube. Chỉ các góc nhìn có ngữ nghĩa chung như ngày, vùng và loại dịch vụ mới phù hợp cho so sánh liên nguồn.

Chuỗi xử lý không ép mọi dịch vụ vào một tập measure tài chính chung. Daily Financial chỉ lấy nguồn có tài chính, còn Zone Traffic có thể thống nhất các nguồn theo sự kiện đón trả. Khi một trường xuất hiện từ thời kỳ mới, file lịch sử được xử lý theo danh sách optional của hợp đồng; thiếu cột optional khác với thiếu một cột thiết yếu.
## 1.4 Từ điển dữ liệu nguồn
Các bảng trong mục này liệt kê toàn bộ cột của hợp đồng extract đang sử dụng. Kiểu tiếp nhận CSV là chuỗi để giữ nguyên giá trị nguồn trước chuẩn hóa; kiểu phân tích và đơn vị được giải thích ở cột mô tả. Cột thiết yếu phải có trong header, nhưng điều đó không đồng nghĩa mọi giá trị trong cột đều khác NULL. Một giá trị thiếu còn phải qua kiểm tra chất lượng tại Transform.
### 1.4.1 Các trường dữ liệu Yellow
@source yellow
### 1.4.2 Các trường dữ liệu Green
@source green
### 1.4.3 Các trường dữ liệu FHV
@source fhv
### 1.4.4 Các trường dữ liệu HVFHV
@source fhvhv
### 1.4.5 Các trường dữ liệu Taxi Zone Lookup
@source lookup
## 1.5 Đánh giá chất lượng và giới hạn dữ liệu
### 1.5.1 Dữ liệu thiếu và giá trị không xác định
NULL biểu thị giá trị không được nguồn cung cấp hoặc không chuyển được theo quy tắc, còn 0 có thể là giá trị được ghi nhận thật. Vì vậy phép tính trung bình chỉ sử dụng số dòng có giá trị tương ứng; không dùng tổng số chuyến làm mẫu số cho mọi measure. Đối với thuộc tính phân loại, Unknown giữ chuyến trong tổng thể nhưng chỉ ra rằng bối cảnh chưa được xác định đầy đủ.

Hệ thống phân biệt mã nguồn NULL với mã có giá trị nhưng chưa tra được dimension. Trường hợp thứ hai có khả năng được sửa khi bổ sung mapping và có thể làm file được chọn nạp lại. Phân biệt này giúp tránh đọc lại mọi file chỉ vì nguồn vốn không cung cấp một thuộc tính.
### 1.5.2 Dữ liệu không hợp lệ và giá trị bất thường
Nhóm điều kiện cốt lõi gồm thời gian pickup hoặc dropoff không hợp lệ, thời lượng không dương, thời lượng vượt ngưỡng 48 giờ và quãng đường thiếu hoặc âm ở nguồn yêu cầu quãng đường. Các điều kiện này xác định IsCoreValid. Những vấn đề như vị trí chưa xác định, số hành khách không hợp lý, khoảng cách bằng 0 hoặc thiếu một khoản tiền có thể được ghi vào QualityIssue theo nhánh quy tắc cụ thể.

Một dòng có cảnh báo chưa chắc là dòng bị loại. Ví dụ, thời gian hợp lệ nhưng vị trí thiếu có thể vẫn đóng góp vào số chuyến và thành viên Unknown; nếu loại bỏ hoàn toàn sẽ làm giảm nhu cầu quan sát được. Ngược lại, không nên giữ một dòng có dropoff trước pickup rồi cộng thời lượng âm vào báo cáo. Các quy tắc và dấu vết lỗi được lưu để giải thích chênh lệch từ nguồn đến kho.
### 1.5.3 Khác biệt cấu trúc dữ liệu giữa các thời kỳ
Converter chấp nhận khác biệt hoa thường trong tên cột nhưng từ chối tên trùng không phân biệt hoa thường, cột ngoài hợp đồng và cột thiết yếu bị thiếu. Cột optional có thể được bổ sung NULL khi không tồn tại trong phiên bản nguồn. Đây là kiểm soát schema drift có chủ đích: dừng để xem xét thay đổi sẽ an toàn hơn việc nạp lệch thứ tự cột.

Từ năm 2025, các nguồn liên quan có thêm cbd_congestion_fee theo tài liệu TLC. Hợp đồng dự án đã chứa trường này. Đối với file cũ, giá trị thiếu không được giải thích như một khoản phí đã thu bằng 0 trong mọi phép so sánh; cần đọc cùng phạm vi thời gian và quy tắc tài chính của nguồn.
### 1.5.4 Giới hạn của dữ liệu dùng trong đồ án
Lần rà soát lưu trong dự án ghi nhận 56 file chuyến, mỗi file giới hạn 10.000 dòng đầu, tương ứng 560.000 dòng clean. Tập này có 558.183 dòng hợp lệ và 1.817 dòng bị loại theo điều kiện cốt lõi. Các con số là ảnh chụp bằng chứng, không phải số liệu hiện tại của nguồn TLC và không phải kết quả chạy mới khi viết báo cáo.

Lấy các dòng đầu có thể làm dữ liệu chỉ bao phủ một phần đầu tháng. Bởi vậy biểu đồ theo giờ, ngày hoặc dịch vụ chỉ mô tả tập đã nạp, chưa cho phép kết luận giờ cao điểm toàn tháng hoặc thị phần toàn thành phố. Kho không có đầy đủ chi phí doanh nghiệp, danh tính tài xế hay dữ liệu đối chứng để suy luận lợi nhuận ròng và tác động nhân quả của chính sách.
## 1.6 Các yêu cầu và câu hỏi phân tích nghiệp vụ
Yêu cầu phân tích được chia thành nhu cầu chuyến đi, đặc điểm phục vụ, tài chính và điều phối. Mỗi yêu cầu phải xác định nguồn có dữ liệu phù hợp, dimension dùng lọc và chỉ tiêu cần đo. Ma trận dưới đây đồng thời là cơ sở kiểm tra tính đầy đủ của các dashboard ở Chương 5.
@questions

# CHƯƠNG 2 PHÂN TÍCH VÀ THIẾT KẾ KHO DỮ LIỆU
## 2.1 Kiến trúc tổng thể của hệ thống
### 2.1.1 Các thành phần và công nghệ sử dụng
SQL Server lưu dữ liệu Staging, clean và DWH; SSIS thể hiện luồng điều phối và các package xử lý; Python thực hiện tải, chuyển đổi và kiểm tra file; PowerShell điều phối tiến trình, thực thi SQL và giao tiếp với SSAS. SSAS Multidimensional tổ chức dimension, measure group và cube; Power BI Desktop trình bày kết quả qua kết nối live.

Sự phối hợp này phản ánh đường chạy hiện có của dự án. Không mô tả SSIS như công cụ trực tiếp chạy toàn bộ Data Flow nếu Master thực tế đang gọi runner. Tương tự, không gọi các project Power BI là mô hình import khi chúng tham chiếu cube trên SSAS. Mỗi công nghệ có trách nhiệm cụ thể và được đối chiếu ở các chương triển khai.
### 2.1.2 Các lớp dữ liệu từ nguồn đến báo cáo
Raw giữ file Parquet gốc; CSV tạo hợp đồng tiếp nhận ổn định; wrk là vùng đệm nạp; stg giữ nội dung nguồn đã nhận cùng thông tin file; clean lưu dữ liệu được chuẩn hóa và kết quả kiểm tra chất lượng. DWH chứa các dimension và fact phục vụ phân tích. SSAS đọc DWH và xây cấu trúc đa chiều; Power BI truy vấn các cube đã được xử lý.

Việc tách các lớp cho phép truy tìm nơi phát sinh chênh lệch. Khi số dòng fact thấp hơn nguồn, có thể đối chiếu số dòng CSV, staging, clean hợp lệ và checkpoint của file. Không phải mọi lớp đều là bản sao có thể xóa tùy ý: lineage, log và trạng thái hoàn tất là điều kiện để chạy lại đúng phạm vi.
### 2.1.3 Luồng dữ liệu tổng thể
Luồng xử lý đi từ lựa chọn tháng và nguồn, tiếp nhận file, chuẩn hóa, nạp dimension, nạp transaction fact, dựng snapshot, process SSAS rồi khai thác báo cáo. Điều kiện chuyển bước dựa trên kiểm tra đầu ra của bước trước. DWH có dữ liệu mới nhưng SSAS chưa process có thể khiến Power BI vẫn nhìn thấy dữ liệu của lần xử lý trước.
@figure architecture
## 2.2 Xác định các quy trình nghiệp vụ cần phân tích
Ba quy trình mức giao dịch tương ứng nhóm chuyến YellowGreen, FHV và HVFHV. Chúng có cùng khái niệm chuyến đi nhưng khác tập thuộc tính và phép đo, do đó được giữ ở ba fact. Ba quy trình mức tổng hợp là tài chính theo ngày, lưu lượng vùng theo thời điểm sự kiện và hiệu suất base theo ngày.

Mỗi snapshot được dựng từ các transaction fact phù hợp chứ không phải từ việc nối các fact theo ngày. Nếu nối hai fact giao dịch chỉ bằng ngày hoặc vùng, một chuyến của nguồn này có thể khớp nhiều chuyến của nguồn khác và làm nhân số lượng. Thiết kế tổng hợp trước theo grain chung tránh lỗi này và tạo phạm vi phân tích rõ ràng cho từng cube.
## 2.3 Xây dựng ma trận nghiệp vụ Data Warehouse Bus Matrix
Bus Matrix xác định những chiều được chia sẻ giữa các quy trình, cùng vai trò của chúng. Ngày và địa lý có nhiều vai trò nên ký hiệu có mặt trong ma trận chỉ thể hiện sự tham gia, không đủ để xác định cột nối. Danh mục quan hệ chi tiết ở mục 2.8 bổ sung khóa ngoại và vai trò cụ thể.
@bus
## 2.4 Lựa chọn mô hình kho dữ liệu
### 2.4.1 Cơ sở lựa chọn Galaxy Schema
Galaxy Schema phù hợp vì hệ thống có nhiều fact cùng sử dụng các dimension ngày, giờ, vùng và loại dịch vụ. So với việc tạo các star schema hoàn toàn độc lập, dimension dùng chung giúp cùng một vùng hoặc ngày được diễn giải thống nhất. So với một fact rất rộng chứa mọi cột, ba fact giao dịch riêng hạn chế các measure không có nghĩa với từng nguồn.

Trong thiết kế này, sự dùng chung nằm ở dimension và quy tắc nghiệp vụ; không tạo một phép cộng tự động qua tất cả cube. Tổng liên nguồn chỉ hợp lệ khi cùng đơn vị sự kiện, cùng phạm vi dữ liệu và cùng bộ lọc. Các snapshot bổ sung tốc độ và sự thuận tiện cho những câu hỏi tổng hợp đã được xác định trước.
### 2.4.2 Dimension dùng chung và dimension đặc thù
Dim_Date, Dim_Time, Dim_Location và Dim_ServiceType là những chiều dùng chung chủ yếu. Dim_Base và Dim_HVFHSProvider phù hợp với nghiệp vụ điều phối và nguồn HVFHV; Dim_Vendor, Dim_PaymentType, Dim_RateCode và Dim_PassengerGroup mô tả taxi truyền thống. Các chiều cờ được tách theo nhóm nguồn để không gộp những cờ có ý nghĩa khác nhau.

Không áp dụng một dimension cho fact chỉ vì tên thuộc tính có vẻ tương tự. VendorID của YellowGreen không thay HVFHS license; base không thay provider; payment type không mô tả thanh toán FHV khi nguồn không có trường tương ứng. Việc xác định đúng dimension đặc thù cũng quyết định Dimension Usage của các cube.
### 2.4.3 Dimension đóng nhiều vai trò
Dim_Date được dùng ở các vai trò Pickup, Dropoff, Request, On Scene hoặc Snapshot; Dim_Time giữ các vai trò giờ tương ứng. Dim_Location được dùng làm Pickup Location và Dropoff Location trong transaction fact, còn snapshot Zone Traffic sử dụng vai trò vị trí của sự kiện. Một dimension vật lý được tái sử dụng qua nhiều khóa ngoại thay vì nhân bản toàn bộ danh mục.

Dim_Base cũng xuất hiện ở DispatchBaseKey, OriginBaseKey và AffiliatedBaseKey tùy nguồn. Ví dụ lọc Dispatch Base trả lời câu hỏi về đơn vị điều phối, trong khi lọc Origin Base hỏi nơi nhận yêu cầu ban đầu. Gộp các vai trò thành một khóa base duy nhất sẽ làm mất khả năng phân biệt hai trách nhiệm này.
## 2.5 Thiết kế các bảng chiều
Mỗi bảng chiều dưới đây trình bày ý nghĩa, khóa nghiệp vụ, khóa thay thế và toàn bộ thuộc tính trong metadata đã lưu. Dòng khóa 0 là thành viên Unknown. Kiểu chuỗi được hiển thị theo số ký tự; metadata nvarchar gốc lưu độ dài byte nên phải chia hai. Bản chụp columns.json không có precision và scale của decimal, do đó cấu hình số thập phân chính xác phải đối chiếu DDL và biểu thức chuyển kiểu trong đặc tả SQL, không suy ra từ kích thước byte.
### 2.5.1 Nhóm chiều ngày và thời gian
Dim_Date tách lịch khỏi sự kiện chuyến đi, cho phép cùng một cấu trúc năm quý tháng ngày được dùng ở mọi fact. Khóa ngày phục vụ join, FullDate phục vụ hiển thị và sắp xếp. IsWeekend được dùng theo lịch seed; IsHoliday chưa có lịch ngày lễ đã được xác nhận nên chưa đủ cơ sở phân tích nhu cầu ngày lễ.

Dim_Time lưu đến phút và cho phép roll up lên giờ hoặc TimeBand. Khóa phút hợp lệ từ 1 đến 1440, khóa 0 dành Unknown để phân biệt thiếu giờ với đúng 00 giờ. Khi phân cấp lên giờ, khóa cần giữ sự phân biệt này; chỉ dùng HourNumber có thể gộp Unknown với nửa đêm.
@dims Dim_Date Dim_Time
### 2.5.2 Nhóm chiều địa lý
Dim_Location sử dụng LocationID làm mã nguồn và LocationKey làm khóa nội bộ. Borough, ZoneName và ServiceZone mô tả vùng ở các mức khác nhau. Hierarchy Borough đến Zone cho phép từ phân tích quận drill xuống từng vùng, nhưng không tự cung cấp tọa độ hoặc thông tin tuyến đường chi tiết.

Cập nhật tên vùng hiện áp dụng SCD Type 1, nghĩa là ghi đè thuộc tính hiện hành trên cùng khóa. Nếu cần tái hiện tên vùng đúng theo từng giai đoạn lịch sử thì phải thiết kế thêm hiệu lực và phiên bản; báo cáo không coi cơ chế đó đã tồn tại. Một mã vùng nguồn chưa được tra cứu được ánh xạ Unknown có kiểm soát và có thể được xử lý lại khi mapping bổ sung.
@dims Dim_Location
### 2.5.3 Nhóm chiều dịch vụ và nhà cung cấp
Dim_ServiceType phân biệt Yellow, Green, FHV và HVFHV, là chiều quan trọng khi tổng hợp liên nguồn. Dim_Vendor giải mã nhà cung cấp công nghệ taxi. Dim_HVFHSProvider giải mã giấy phép nhà cung cấp dịch vụ quy mô lớn. Ba chiều có nhiệm vụ khác nhau nên không được thay thế bằng một cột tên doanh nghiệp chung.

Trong YellowGreen fact, ServiceTypeKey xác định nguồn dù các trường tiền được đặt chung tên. Trong HVFHV fact, provider cho phép phân tích theo giấy phép. Các mã doanh nghiệp trong danh mục là thông tin gắn với kỳ dữ liệu; không dùng danh sách lịch sử để khẳng định doanh nghiệp vẫn hoạt động ở hiện tại.
@dims Dim_ServiceType Dim_Vendor Dim_HVFHSProvider
### 2.5.4 Nhóm chiều base điều phối
Dim_Base lưu số giấy phép, tên và nhóm base nếu có. BaseNumber là mã nghiệp vụ; BaseKey là khóa thay thế được fact tham chiếu. Loader bổ sung mã base phát hiện từ tập file cần nạp, tránh tạo một dòng fact với mã nghiệp vụ nằm trực tiếp trong các cột khóa dimension.

Thiết kế hiện chủ yếu thêm mã base, chưa có SCD Type 2 và lookup theo khoảng hiệu lực. Các vai trò dispatch, origin và affiliated dùng cùng bảng chiều nhưng không có nghĩa ba khóa luôn bằng nhau. Việc phân tích hiệu suất phải chỉ rõ vai trò base đã chọn.
@dims Dim_Base
### 2.5.5 Nhóm chiều phân loại chuyến đi và thanh toán
Dim_RateCode lưu loại biểu giá; Dim_PaymentType lưu phương thức hoặc tình trạng thanh toán; Dim_TripType lưu cách nhận chuyến Green; Dim_PassengerGroup tạo nhóm số hành khách để phân tích. Những bảng này đưa thuộc tính phân loại ra khỏi fact và cung cấp tên hiển thị thống nhất cho báo cáo.

Mã thanh toán là mã danh mục, không phải giá trị tiền. PassengerCount trong fact vẫn là số hành khách của dòng; PassengerGroup chỉ bổ sung cách phân loại. Khi nguồn không cung cấp một phân loại, loader sử dụng quy tắc Unknown hoặc không áp dụng của mô hình, không tự suy ra từ cước hoặc loại xe.
@dims Dim_RateCode Dim_PaymentType Dim_TripType Dim_PassengerGroup
### 2.5.6 Nhóm chiều cờ nghiệp vụ
Dim_TaxiFlags giữ cờ store and forward. Dim_FHVFlags giữ trạng thái đi chung được chuẩn hóa từ SR_Flag. Dim_HVFHVFlags giữ tổ hợp cờ yêu cầu đi chung, đã ghép, Access A Ride, yêu cầu WAV và chuyến thực hiện bằng WAV. Các bảng này là junk dimension, gom tổ hợp cờ để fact tham chiếu bằng một khóa.

Trạng thái U được giữ khi chưa biết; không tự chuyển NULL thành N. Cờ yêu cầu đi chung khác với cờ đã chia sẻ xe; tương tự cờ yêu cầu WAV khác với cờ chuyến xảy ra bằng xe WAV. Sự khác biệt này quyết định cách xây tỷ lệ nghiệp vụ và là lý do không dùng mọi phép chia giữa các cờ như một KPI tỷ lệ đáp ứng.
@dims Dim_TaxiFlags Dim_FHVFlags Dim_HVFHVFlags
### 2.5.7 Chiều lô nạp dữ liệu
Dim_LoadBatch lưu ngữ cảnh nhóm xử lý như dataset, năm tháng và trạng thái lô. Trong bằng chứng hiện có, đây là nhóm nạp suy từ tháng pickup và SourceFileName có thể NULL. Vì vậy không coi LoadBatchKey là định danh file nguồn đầy đủ.

Lineage theo file phải dùng SourceDataset và SourceKey trong fact, kết hợp log Extract, Transform và DWH. Một tháng pickup có thể chứa chuyến từ nhiều file nguồn và một file tháng có thể chứa thời điểm ngoài tháng danh nghĩa. Sự phân biệt này giúp tránh truy vết sai khi nguồn được hiệu chỉnh.
@dims Dim_LoadBatch
## 2.6 Thiết kế các bảng sự kiện
### 2.6.1 Fact_YellowGreen_Trips
Loại fact là Transaction Fact. Grain là một lượt xuất hiện chuyến Yellow hoặc Green hợp lệ trong một file nguồn. Khóa TripKey là khóa thay thế nội bộ; nội dung bản ghi, nguồn và thứ tự xuất hiện của dòng trùng được dùng khi đồng bộ. Không xem TripKey là mã chuyến kinh doanh được TLC bảo đảm bền vững.

Lý do gộp Yellow và Green là hai nguồn có nhiều measure đồng nhất về thời gian, quãng đường và cước taxi. ServiceTypeKey bảo toàn sự phân biệt dịch vụ. Fact nối đến ngày, giờ, vùng ở hai vai trò đón trả cùng các chiều vendor, biểu giá, thanh toán, loại chuyến, cờ taxi, nhóm hành khách và lô nạp.

TripCount cộng để tính số chuyến; PassengerCount cộng để tính số hành khách được ghi nhận; các khoản tiền và khoảng cách cộng trong phạm vi phù hợp. AverageSpeedMPH ở mức dòng không có tính cộng dồn. Tốc độ toàn nhóm phải tính từ tổng quãng đường và thời lượng của cùng tập dòng hợp lệ, thay vì cộng hoặc trung bình đơn giản tốc độ từng chuyến.
@fact Fact_YellowGreen_Trips
### 2.6.2 Fact_FHV_Trips
Loại fact là Transaction Fact; grain là một lượt xuất hiện chuyến FHV hợp lệ từ file nguồn. Các khóa ngày, giờ và vùng ghi hai vai trò pickup, dropoff; base có vai trò dispatch và affiliated. FHVFlagKey giữ cờ đi chung theo quy tắc nguồn đã chuẩn hóa.

Nguồn không cung cấp đầy đủ quãng đường và các khoản thu nên fact chỉ tập trung số chuyến và thời lượng cùng ngữ cảnh điều phối. Đây là lựa chọn bảo toàn ý nghĩa dữ liệu, không phải thiếu một measure cần điền 0. Thời lượng được tính từ pickup đến dropoff và kiểm tra điều kiện cốt lõi trước khi nạp.

Mọi tổng hợp theo địa lý cần giữ Unknown vì tập FHV có thể thiếu nhiều vị trí. Thống kê trên các vùng đã biết phải nêu bộ lọc; nếu âm thầm bỏ Unknown, tổng trên bản đồ có thể thấp hơn card tổng chuyến mà không có giải thích.
@fact Fact_FHV_Trips
### 2.6.3 Fact_HVFHV_Trips
Loại fact là Transaction Fact; grain là một lượt xuất hiện chuyến HVFHV hợp lệ. Các mốc Request, On Scene, Pickup và Dropoff cùng nằm trên một dòng để phân tích chờ và phục vụ. Tuy có nhiều mốc, fact không được coi là accumulating snapshot cập nhật tiến trình trực tiếp vì đầu vào đang là bản ghi chuyến được công bố theo file.

Fact tham chiếu provider, base điều phối, base nhận yêu cầu và dimension cờ chuyên biệt. Các measure gồm quãng đường, thời lượng, thời gian chờ, thời gian từ on scene đến pickup, cước cơ bản, các khoản thuế phí, tip, tiền tài xế và tổng tiền hành khách theo công thức nguồn trong loader. WaitingTimeSeconds sử dụng Request đến Pickup khi thứ tự thời gian hợp lệ; đây không phải luôn là thời gian xe đến điểm đón.

GrossPassengerAmount được xây từ các thành phần tài chính theo SQL, tách khỏi DriverPayAmount. Chênh lệch hai đại lượng không được đặt tên là lợi nhuận vì chưa có đầy đủ cấu phần chi phí và quy tắc kế toán. Các chỉ tiêu trung bình giữ số dòng hợp lệ làm mẫu số riêng cho từng measure.
@fact Fact_HVFHV_Trips
### 2.6.4 Fact_Daily_Financial_Snapshot
Loại fact là Periodic Snapshot ở grain DateKey và ServiceTypeKey. Một dòng mô tả tổng tài chính của một ngày và một dịch vụ có dữ liệu tài chính. Khóa chính ghép bảo đảm không có hai dòng cùng tổ hợp này. FHV không được đưa vào tổng tiền bằng các giá trị giả định.

Các measure tổng gồm số chuyến, quãng đường, tiền khách trả, tip, thuế phí và tiền tài xế. NULL giữ ý nghĩa thiếu hoặc không áp dụng ở những cấu phần nguồn không cung cấp. Snapshot phục vụ so sánh tài chính theo ngày và dịch vụ, nhưng không được cộng cùng fact giao dịch để tạo tổng mới vì đó là hai mức biểu diễn của cùng dữ liệu.
@fact Fact_Daily_Financial_Snapshot
### 2.6.5 Fact_Zone_Traffic_Snapshot
Loại fact là Periodic Snapshot; grain vật lý là DateKey, TimeKey, LocationKey và ServiceTypeKey. TimeKey có mức phút nên việc trình bày theo giờ là roll up qua Dim_Time, không thay đổi grain của bảng. Khóa chính ghép bốn cột ngăn trùng nhóm tổng hợp.

Pickup được nhóm theo ngày, phút và vùng đón; dropoff được nhóm theo ngày, phút và vùng trả. Hai tập sự kiện được kết hợp để tính TotalPickups và TotalDropoffs ở cùng grain. Một chuyến có thể đón hôm trước và trả hôm sau nên không yêu cầu hai measure bằng nhau ở từng ngày hoặc vùng. Chỉ ở phạm vi đối soát phù hợp mới so tổng số sự kiện với số chuyến nguồn.
@fact Fact_Zone_Traffic_Snapshot
### 2.6.6 Fact_Base_Performance_Snapshot
Loại fact là Periodic Snapshot; grain là ngày, base điều phối, dịch vụ và provider. Provider có thể là Unknown hoặc không áp dụng ở nguồn không có giấy phép HVFHS. Khóa ghép ngăn việc trộn các nhà cung cấp hoặc dịch vụ chỉ vì dùng cùng base.

Bảng lưu tổng thời lượng và DurationTripCount, tổng chờ và WaitingTripCount để tính lại trung bình khi lọc hoặc roll up. Các cột trung bình lưu sẵn không được cộng trực tiếp và không phải mẫu số để lấy trung bình các nhóm. Cờ đi chung, WAV và tiền tài xế được tổng hợp theo phạm vi nguồn có trường tương ứng.

Tổng WAV matches chia tổng WAV requests không mặc nhiên là tỷ lệ phục vụ yêu cầu: hai cờ có định nghĩa khác nhau và tử số chưa được bảo đảm là tập con của mẫu số. Chỉ số đã được ẩn trong bản hardening của SSAS; số đếm gốc vẫn được giữ để không sửa dữ liệu nhằm ép một tỷ lệ về giới hạn mong muốn.
@fact Fact_Base_Performance_Snapshot
## 2.7 Thiết kế phân cấp và quy tắc tổng hợp dữ liệu
Calendar đi theo Year → Quarter → Month → Date. Key của Quarter phải chứa năm và quý; key của Month phải chứa năm và tháng. Nếu chỉ dùng MonthNumber, tháng 1 của các năm sẽ bị gộp thành một member trong hierarchy. Dim_Time tổ chức TimeBand → Hour → Time, còn Dim_Location dùng Borough → Zone.

Measure cộng dồn như TripCount, khoảng cách và tiền được cộng theo đúng grain. Measure tỷ lệ và trung bình được tính từ tổng tử và tổng mẫu hợp lệ ở phạm vi lọc mới. Mẫu số bằng 0 hoặc thiếu trả NULL. Các phép cộng khác đơn vị sự kiện, chẳng hạn cộng lượt đón với lượt trả rồi gọi là số chuyến, bị loại khỏi định nghĩa chỉ tiêu.
@hierarchies
## 2.8 Thiết kế vật lý và toàn vẹn dữ liệu
### 2.8.1 Kiểu dữ liệu khóa chính và khóa ngoại
Dimension dùng các khóa nội bộ để fact join ổn định; thuộc tính mã nguồn được giữ riêng để tra cứu. Các fact giao dịch dùng TripKey làm khóa nội bộ của dòng, còn snapshot dùng khóa ghép đúng grain. Khóa ngoại nối đến các bảng chiều giúp phát hiện nạp sai tham chiếu trước khi dữ liệu đi vào SSAS.

Kiểu số được chọn theo ngữ nghĩa: số đếm dùng kiểu nguyên, quãng đường dùng decimal có phần thập phân, tiền dùng decimal và thời điểm dùng datetime2 trong lớp chuẩn hóa. Không dùng kiểu chuỗi của CSV làm kiểu phân tích trong DWH. Các kiểu chính xác và khả năng NULL được trình bày ở từ điển từng bảng; DDL nguyên văn nằm tại Phụ lục A.
@foreignkeys
### 2.8.2 Khóa thay thế và thành viên Unknown
Surrogate key tách định danh nội bộ khỏi mã nghiệp vụ, hỗ trợ dùng chung dimension giữa các nguồn. Dòng key bằng 0 được seed ở mỗi dimension để biểu diễn chưa xác định. Unknown giữ sự kiện trong tổng nhưng không khẳng định giá trị nghiệp vụ đã biết; cần cho phép người sử dụng nhìn thấy nhóm này trên báo cáo.

Unknown trong bảng dimension khác cơ chế UnknownMember bổ sung của SSAS. Nếu loader ánh xạ đúng về 0, fact tham chiếu một thành viên dữ liệu bình thường. Nếu có khóa không phân giải ngoài quy ước, SSAS vẫn phải báo lỗi theo ErrorConfiguration thay vì bỏ qua hoặc tăng giới hạn lỗi để process cho xong.
### 2.8.3 Chỉ mục phục vụ nạp và truy vấn
Chỉ mục theo SourceDataset và SourceKey, có RecordHash được INCLUDE, hỗ trợ lấy đúng tập fact của một file khi đồng bộ. Clean có chỉ mục theo TaxiType và ETLSourceKey để kiểm tra lineage và chọn phạm vi Transform. Các khóa chính dimension và snapshot cũng hỗ trợ join, lookup và bảo vệ tính duy nhất.

Chỉ mục được thiết kế theo đường truy cập thực tế chứ không có nghĩa mọi truy vấn đã tối ưu. Dữ liệu demo nhỏ chưa đủ để kết luận hiệu năng toàn tập; cần đo chi phí tải, ghi log và process khi tăng dữ liệu. Snapshot rebuild toàn bảng và SSAS ProcessFull vẫn là những phần có chi phí phụ thuộc kích thước toàn kho.
### 2.8.4 Quản lý thay đổi thuộc tính dimension
Dim_Location áp dụng cập nhật Type 1 với các thuộc tính hiện hành. Các mã base mới được bổ sung nhưng chưa có cơ chế phiên bản Type 2 gắn khoảng hiệu lực. Vì vậy phân tích lịch sử sử dụng thuộc tính chiều theo thiết kế hiện có, không tái dựng được mọi thay đổi tên hoặc phân loại theo thời gian.

Khi mapping một nhóm dimension thay đổi, DWH loader có thể chọn lại file còn Unknown có khả năng sửa trong nhóm đó. Đổi tên vùng trên cùng khóa không nhất thiết yêu cầu nạp lại fact. Thay quy tắc ánh xạ hoặc seed ngày giờ cần nâng LoaderVersion hoặc ForceReload phạm vi liên quan; không kỳ vọng checkpoint tự phát hiện mọi sửa đổi thủ công ngoài pipeline.
### 2.8.5 Lưu thông tin truy vết nguồn dữ liệu
Lineage của fact dựa trên SourceDataset, SourceKey và RecordHash, đối chiếu với checkpoint Extract, Transform và DWH. FileHash xác định nội dung CSV đã nhận; RuleVersion và ZoneHash mô tả bối cảnh Transform; LoaderVersion xác định logic đồng bộ fact. Một record hash không thay thế lịch sử trạng thái của cả file.

FactChangeAudit giữ bản ghi cũ trước các thao tác thay thế theo thiết kế loader. Khi nguồn hiệu chỉnh, TripKey có thể đổi do delete và insert; người vận hành cần truy vết bằng nguồn, payload và audit, không dựa duy nhất vào surrogate key. Xóa file local không phải quy trình tombstone và không tự yêu cầu xóa fact lịch sử.
## 2.9 Sơ đồ mô hình kho dữ liệu hoàn chỉnh
Mô hình gồm ba transaction fact cùng ba snapshot, chia sẻ các bảng chiều theo Bus Matrix. Sơ đồ sau phân biệt quan hệ tham chiếu chiều với luồng tạo snapshot; danh mục khóa ngoại là đặc tả chi tiết của từng quan hệ. Thiết kế không tạo quan hệ join nhiều nhiều trực tiếp giữa các transaction fact.
@figure galaxy

# CHƯƠNG 3 XÂY DỰNG QUY TRÌNH ETL
## 3.1 Mục tiêu và kiến trúc ETL
ETL chuyển dữ liệu file thành các bảng có kiểu và ý nghĩa thống nhất, đồng thời duy trì bằng chứng để kiểm tra việc nạp. Điểm vào gồm Master SSIS hoặc runner theo chế độ vận hành đã cấu hình. Luồng chính giữ thứ tự Extract → Transform → Dwh → Aggregates → Ssas; mỗi stage chỉ được coi hoàn tất khi kết quả và log StageComplete đáp ứng điều kiện.

Master dùng Execute Process Task gọi controller, controller gọi Invoke-NYCTaxiPipeline.ps1. Runner dùng Python cho file, SqlBulkCopy cho wrk và SQL nhúng trong package cho các tác vụ nghiệp vụ. Các package con vẫn chứa mô tả luồng native, nhưng chạy trực tiếp chúng là một đường khác; không chạy song song package con với Master vì chưa phải mọi đường đều dùng chung khóa điều phối.
@figure etl
## 3.2 Chuẩn bị môi trường và cấu hình
### 3.2.1 Cơ sở dữ liệu và cấu trúc thư mục
NYCTaxi_Staging chứa vùng làm việc, staging, clean và các đối tượng kiểm soát liên quan; NYCTaxi_DWH chứa các dimension, fact và log điều phối cấp kho. Các thư mục raw, csv và quarantine nằm dưới DataRoot. Log của runner nằm theo RunId trong etl/logs, tách với dữ liệu nguồn để vẫn đọc được khi một file lỗi.

Bản source trong workspace dùng etl/packages để lưu package, trong khi PackageRoot mặc định của runner trỏ bản package ở thư mục dự án ETL triển khai trên máy. Khi chuyển môi trường cần đặt lại PackageRoot, ScriptsRoot, DataRoot, PythonExe và server đồng nhất. Có file source tại workspace không chứng minh runner đang đọc đúng file nếu tham số trỏ nơi khác.
### 3.2.2 Các kết nối sử dụng
Kết nối SQL của runner dùng Windows Integrated Security, Connect Timeout 15 giây và Application Name riêng cho pipeline. Helper SQL đặt CommandTimeout 1800 giây. SqlBulkCopy cũng có timeout riêng; SSAS được truy cập bằng AMO và XMLA với quyền xử lý database. Tài khoản dịch vụ SSAS cần đọc DWH qua Data Source của mô hình.

Connection Manager trong package native mô tả OLE DB hoặc Flat File theo đường chạy đó. Không nhầm thuộc tính của Connection Manager với kết nối .NET thực tế mà runner mở. Khi mô tả hoặc kiểm tra lỗi, phải xác định lỗi thuộc SQL connection, trình đọc CSV, tiến trình Python hay kết nối SSAS để không thay cấu hình sai tầng.
### 3.2.3 Tham số biến và phạm vi xử lý
Các tham số chính gồm khoảng tháng, MaxRows, server SQL, server SSAS, các thư mục, đường dẫn Python, RunId, InvocationId và Stage. Offline bỏ download nhưng vẫn kiểm tra file có sẵn; RefreshSource nhận lại nguồn để dùng bản hiệu chỉnh. InjectFailure là tham số hỗ trợ kiểm thử, không dùng trong vận hành bình thường.

Master có pStartMonth, pEndMonth, pMaxRows, pResumeRunId, pStartStage, pMaxRetries và pShowMonitor. Mặc định Master và runner có thể khác nhau: package demo được lưu với tháng 2021 02 và 10000 dòng, trong khi runner mặc định 2025 01 đến 2025 12 và 100000 dòng. Giá trị thực được truyền khi chạy mới là cấu hình quyết định phạm vi, không chỉ dựa trên mặc định của một file script.
@parameters
### 3.2.4 Kiểm tra điều kiện trước khi chạy
Preflight xác nhận các đường dẫn bắt buộc, kết nối NYCTaxi_Staging và NYCTaxi_DWH, cùng khả năng import pyarrow và lxml bằng Python đã chọn. Khoảng tháng phải hợp lệ, StartMonth không sau EndMonth và năm nằm trong phạm vi chương trình. Kiểm tra này phát hiện lỗi môi trường trước khi bắt đầu tải hoặc sửa dữ liệu.

Preflight đạt chưa đủ để chứng minh đủ quyền process SSAS hay dữ liệu nguồn đúng nghiệp vụ. Các điều kiện đó được kiểm tra tại stage tương ứng. Người vận hành cần giữ cấu hình đầu vào, phiên bản source và quyền truy cập ổn định trong cùng một RunId; sửa code giữa hai lần resume chưa được ConfigHash bảo vệ đầy đủ như một manifest phiên bản.
## 3.3 Xây dựng luồng điều phối chính
### 3.3.1 Cấu trúc package Master
PKG_00_Master bắt đầu bằng EPT_00_Open_Monitor, sau đó lần lượt EPT_01_Extract, EPT_02_Transform, EPT_03_Dwh, EPT_04_Aggregates, EPT_05_Ssas và EPT_99_Complete. Monitor mở cửa sổ theo dõi riêng, không chặn xử lý dữ liệu. Complete kiểm tra trạng thái SQL của run đã SUCCEEDED sau stage Ssas và đối soát.

Các đường thành công bảo đảm phụ thuộc tuần tự; nhánh lỗi từ các EPT đi về tác vụ báo lỗi gốc theo điều kiện OR. Một stage thất bại không được cho phép stage phụ thuộc chạy tiếp như đã thành công. Khi ghi lỗi SQL thất bại, log local vẫn giữ nguyên lỗi gốc và RunId để truy vết.
@master
@taskmap
### 3.3.2 Vai trò của SSIS PowerShell và Python
SSIS cung cấp bề mặt package, tham số và luồng điều phối; controller quản lý việc gọi stage, retry, resume và kết quả tiến trình; runner thực hiện chuỗi thao tác cùng checkpoint. Python tải, chuyển đổi và inspect file; các biến đổi nghiệp vụ chính được thực thi bằng SQL đọc từ package thay vì bị viết lại riêng trong Python.

Kiến trúc này có ưu điểm là các quy tắc SQL có một nguồn định nghĩa trong package. Tuy nhiên, tiến độ native Data Flow không phải tiến độ của runner; việc mở tab package con không làm hiển thị các câu SQL của runner đang chạy. Báo cáo triển khai vì vậy mô tả cả đường điều phối và nơi thực thi thực tế.
### 3.3.3 Thứ tự thực thi và điều kiện chuyển bước
Extract phải hoàn tất file và số dòng trước Transform; Transform phải hoàn tất cùng phiên bản trước Dwh; Dwh phải hợp lệ trước Aggregate; snapshot phải nhất quán trước process SSAS. Khi chạy riêng một stage sau Extract, runner yêu cầu StageComplete SUCCEEDED của stage trước trong cùng RunId.

Khi stage trước được chạy lại, các StageComplete thành công phía sau bị đánh INVALIDATED. Quy tắc này ngăn việc dùng kết quả cũ của snapshot hoặc cube sau khi đầu vào thay đổi. Một run chỉ được ghi SUCCEEDED ở cuối đường All hoặc Ssas sau các bước bắt buộc, không phải ngay sau khi nạp fact.
### 3.3.4 Truyền tham số và quản lý mã lần chạy
RunId định danh lượt ETL xuyên các stage. Với lượt mới, Master dùng ExecutionInstanceGUID khi pResumeRunId trống; với resume, dùng RunId người vận hành chỉ định. InvocationId phân biệt từng lần gọi runner và từng lần thử lại, tránh đọc nhầm failure JSON của lần trước.

ConfigHash kiểm tra tháng, giới hạn dòng, server, đường dẫn và chế độ liên quan. Khi dùng lại RunId với cấu hình khác, runner từ chối. Để thay phạm vi tháng hoặc chuyển môi trường phải tạo lượt mới theo quy trình, không sửa tham số của run cũ để làm checkpoint có vẻ hợp lệ.
## 3.4 Xây dựng luồng trích xuất và nạp Staging
### 3.4.1 Tải dữ liệu nguồn
Downloader lựa chọn file theo tháng và dataset, bỏ qua những nguồn chưa có ở mốc đầu của hợp đồng. Dữ liệu được lưu raw trước khi chuyển đổi. RefreshSource yêu cầu nhận lại bản nguồn, còn chế độ Offline bỏ qua mạng nhưng không bỏ qua kiểm tra đầy đủ đầu vào. Thiếu file bắt buộc không được tự hiểu là dataset có 0 chuyến.

Thành công của bước download chỉ khẳng định có đầu vào cần thiết cho bước kế tiếp. Việc tái sử dụng cache còn phải phù hợp signature, cấu hình chuyển đổi và hash. File lỗi tải không được đưa sang parser như một Parquet hợp lệ hoặc được thay bằng file rỗng để pipeline tiếp tục.
### 3.4.2 Chuyển đổi Parquet sang CSV
Converter đọc theo batch nhằm tránh nạp toàn bộ file lớn vào bộ nhớ. Chế độ ssis xuất đúng thứ tự cột trong extract_contract.py, dùng UTF 8 và LF. Cột optional thiếu được xử lý theo hợp đồng; cột lạ và thiếu thiết yếu làm dừng để xem xét schema drift. Dữ liệu được ghi vào file tạm rồi đổi tên khi hoàn tất.

Metadata đi kèm ghi source_file, source_size, source_mtime_ns, dataset, columns, schema_mode, contract_version, encoding, line_ending, rows, source_rows, row_limit, csv_size, csv_mtime_ns và sha256. Điều kiện reuse so khớp thông tin nguồn, chế độ, số dòng, giới hạn và hash; đổi MaxRows từ mẫu sang toàn file làm thay phiên bản đầu vào thay vì sử dụng nhầm CSV cũ.
### 3.4.3 Kiểm tra cấu trúc metadata và số dòng
Inspector đọc file theo dataset và xác nhận header, thứ tự cột, số trường, bề rộng, số dòng, hash và giới hạn. File ngoài khoảng tháng được ghi trạng thái bỏ qua ngoài phạm vi; file trong phạm vi phải đáp ứng hợp đồng. Các trường chuyến ở CSV có bề rộng tiếp nhận 50 ký tự, các trường mô tả lookup ngoài LocationID có bề rộng 255.

Lỗi cấu trúc như thiếu dấu phân cách làm sai số trường phải dừng file. Đây khác lỗi nghiệp vụ của một giá trị hợp lệ về cấu trúc nhưng không phù hợp điều kiện phân tích. Tách hai loại lỗi giúp quarantine đúng đầu vào và tránh quy tắc làm sạch vô tình che một CSV đã bị lệch cột.
### 3.4.4 Nạp dữ liệu vào vùng làm việc
Runner dùng TextFieldParser với dấu phẩy, cho phép trường đặt trong dấu nháy, UTF 8 và không trim toàn bộ chuỗi tại bước đọc. Header tạo các cột chuỗi của DataTable; cột được ánh xạ theo tên vào wrk của dataset. Chuỗi rỗng chuyển DBNull ở tầng nạp, còn các xử lý trim và đổi kiểu nghiệp vụ diễn ra ở Transform.

SqlBulkCopy đặt BatchSize 10000, BulkCopyTimeout 1800 và ghi từng bộ đệm rồi Clear để hạn chế bộ nhớ. Mỗi lần đọc dòng phải kiểm tra số trường bằng số cột. Tiến độ rows trên monitor phản ánh đã ghi wrk, chưa chứng minh dữ liệu đã được commit sang staging hoặc fact. Khi file lỗi, không bỏ qua riêng dòng lỗi CSV rồi báo nạp đầy đủ.

Ở đường chạy package native, Flat File Source, Row Count và OLE DB Destination được cấu hình theo từng dataset. Các cột và bề rộng theo hợp đồng CSV; lỗi chuyển đổi hoặc cắt ngắn giữ chế độ FailComponent theo metadata thay vì âm thầm redirect rồi bỏ dòng. Đường chạy Master hiện dùng parser và SqlBulkCopy của runner, nên cơ chế quarantine theo file thuộc runner, không phải một nhánh Data Flow đã thực thi trong package con. Các thuộc tính component và disposition cột được liệt kê ở Phụ lục A để phân biệt hai đường chạy.
### 3.4.5 Ghi dữ liệu vào Staging và cập nhật trạng thái
usp_BeginExtractFile nhận dataset, đường dẫn, hash, ExpectedRows và RowLimit để xác định file đã nạp đủ hay cần làm lại. File được bulk copy khi cần, sau đó usp_CommitExtractFile kiểm tra số dòng thực và đưa dữ liệu từ wrk vào stg theo đúng file. Các cột ETLSourceKey, ETLFileHash và ETLLoadedAt giữ lineage cho bước sau.

ExtractFileLog phản ánh trạng thái thực, không chỉ sự tồn tại của CSV. Nếu inspect hoặc nạp hay commit thất bại, CSV, sidecar và thông tin lỗi được sao chép vào quarantine theo RunId và dataset; log được cập nhật FAILED khi có thể. Cuối stage, Validate Staging nhận đúng tháng và giới hạn dòng để kiểm tra phạm vi đã chọn trước khi cho Transform chạy.
## 3.5 Xây dựng luồng biến đổi và làm sạch
### 3.5.1 Chuẩn hóa danh mục Taxi Zone
Task setup tạo hoặc kiểm tra các đối tượng clean cần thiết. Transform TaxiZone chuẩn hóa LocationID và các chuỗi Borough, Zone, ServiceZone. Các chuyến đi chỉ được chuẩn hóa sau khi danh mục đã sẵn sàng; task chuyến kiểm tra điều kiện tồn tại lookup trước khi xử lý dữ liệu.

ZoneHash được tính từ danh mục theo thứ tự xác định và tham gia phiên bản Transform. Khi danh mục đổi, những file chịu điều kiện chọn lại được biến đổi để phản ánh kiểm tra vùng mới. Chỉ lưu một lần tên lookup trong thư mục không đủ chứng minh fact đã sử dụng cùng phiên bản danh mục.
### 3.5.2 Xử lý dữ liệu Yellow
Task Yellow lấy các file Extract SUCCEEDED và đủ số dòng, kiểm tra clean hiện có theo SourceKey, rồi lập #Todo cho file mới, đổi hash, đổi rule, đổi ZoneHash hoặc thiếu dữ liệu. Trước khi sửa clean, staging của đúng các file cần xử lý phải khớp số dòng và hash. Phần clean thuộc #Todo được thay thế trong transaction, còn các file đã hoàn tất được giữ.

Các trường tpep được đổi DATETIME2(0); mã số được chuyển có kiểm soát qua số đủ chính xác để không âm thầm cắt phần thập phân; quãng đường và tiền chuyển decimal theo SQL. Store and forward được chuẩn hóa Y, N hoặc chưa biết. DurationSeconds lấy chênh pickup dropoff; TripDistanceKm nhân mile với 1,609344; tốc độ tính khi thời gian dương và quãng đường không âm. Các phép đo suy ra được giới hạn trong tập file vừa làm lại.
### 3.5.3 Xử lý dữ liệu Green
Task Green thực hiện cơ chế chọn file và lineage tương tự Yellow, nhưng đọc các mốc lpep và trường riêng như trip_type, ehail_fee. Kiểu dữ liệu tài chính được chuẩn hóa vào cấu trúc clean dùng chung, đồng thời giữ TaxiType để không mất nguồn dịch vụ. Những khoản phí không có ở một kỳ được giữ theo quy tắc NULL thay vì điền một hằng số tùy ý.

Green và Yellow cùng chịu kiểm tra thời lượng, khoảng cách và cảnh báo hành khách theo nhóm taxi. Việc đưa về một cấu trúc clean không làm trip_type trở thành thuộc tính có nghĩa cho mọi nguồn. Bước load DWH sẽ tra dimension chuyên biệt theo TaxiType và quy tắc seed.
### 3.5.4 Xử lý dữ liệu FHV
Task FHV chuyển pickup, dropoff, mã vùng, base điều phối, base liên kết và SourceSRFlag. Do nguồn không có quãng đường như các nguồn khác, thiếu TripDistanceMiles không được dùng để loại toàn bộ FHV bằng quy tắc áp cho taxi. Các điều kiện thời gian cốt lõi vẫn được kiểm tra để bảo vệ chỉ tiêu thời lượng.

Bản hardening sửa loader để đọc đúng SourceSRFlag, đưa trường này vào hash payload và nâng LoaderVersion riêng FHV. Fixture kiểm tra 1 thành Y, 0 thành N và NULL thành U. Việc sửa mã nguồn không đồng nghĩa toàn bộ fact production đã được nạp lại; lần DWH kế tiếp cần xử lý file FHV theo phiên bản mới và đối soát sau đó.
### 3.5.5 Xử lý dữ liệu HVFHV
Task HVFHV đọc các mốc request, on scene, pickup, dropoff; quãng đường và trip_time nguồn; các thành phần tài chính và cờ nghiệp vụ. Thời lượng thực phục vụ phân tích được tính từ pickup đến dropoff, còn trip_time nguồn được giữ để so sánh. Lệch quá 60 giây giữa hai đại lượng được ghi cảnh báo theo SQL.

RequestWaitSeconds được tính từ request đến pickup khi request không sau pickup. Nếu on scene sau pickup hoặc request thiếu, chất lượng được ghi nhận thay vì tự dựng thời gian. Tổng tiền khách được suy ra theo công thức loader từ các thành phần nguồn; tiền tài xế và tip được giữ riêng. Cờ shared request và shared match không được gộp thành một trường duy nhất.
### 3.5.6 Phân loại bản ghi hợp lệ bị loại và có cảnh báo
IsCoreValid xác định tập được phép nạp fact. QualityIssue ghép các mã lỗi hoặc cảnh báo để một dòng có thể phản ánh nhiều vấn đề. clean.ValidTrip cung cấp tập hợp lệ, clean.RejectedTrip hỗ trợ xem dòng bị loại, clean.WarningTrip giữ các dòng có cảnh báo theo định nghĩa. Không cộng số dòng cảnh báo vào số bị loại vì một dòng cảnh báo có thể vẫn hợp lệ.

Các trường hợp cốt lõi gồm pickup hoặc dropoff không chuyển được, dropoff không sau pickup, thời lượng hơn 48 giờ, và khoảng cách thiếu hoặc âm đối với nguồn không phải FHV. Các cảnh báo còn lại gồm khoảng cách 0, hành khách không hợp lý ở taxi, vị trí Unknown, tổng tiền âm hoặc thiếu, request/on scene sai thứ tự và lệch thời lượng nguồn. Phân loại cụ thể phải theo từng task, không dùng một danh sách diễn giải để thay SQL.
@quality
### 3.5.7 Kiểm tra kết quả sau biến đổi
Task tổng hợp số dòng source, clean, valid, rejected và warning cho các file vừa xử lý. Điều kiện clean bằng ExpectedRows và valid cộng rejected bằng ExpectedRows phải đúng trước khi ghi TransformFileLog. Log giữ FileHash, RuleVersion, ZoneHash, SourceRows, CleanRows, ValidRows, RejectedRows, WarningRows và thời điểm hoàn tất trong cùng transaction với dữ liệu.

Nếu phát hiện staging thiếu lineage hoặc số dòng sai, task rollback và trả lỗi gốc. Transform hiện còn kiểm tra clean lịch sử theo dataset trước khi chọn #Todo, nên chưa thể khẳng định toàn stage chỉ đọc file mới. Checkpoint làm giảm phần biến đổi nhưng không đồng nghĩa mọi truy vấn chuẩn bị đã độc lập với kích thước lịch sử.
## 3.6 Xây dựng luồng nạp kho dữ liệu
### 3.6.1 Xác định file cần xử lý
etl.DwhSourceState đối chiếu Extract và Transform, chỉ nhận bốn dataset chuyến đi đã đầy đủ và cùng phiên bản. Lookup Taxi Zone không phải file fact nên không yêu cầu DwhFileLog giả cho lookup. SourceVersion kết hợp nội dung file, rule, ZoneHash, số dòng và thông tin hoàn tất Transform để nhận biết đầu vào nạp kho.

File cần làm lại khi chưa có checkpoint thành công, SourceVersion hoặc LoaderVersion thay đổi, ForceReload được đánh dấu hoặc mapping khiến file có Unknown cần sửa thuộc phạm vi chọn lại. Bản không đổi có thể được bỏ qua. Lần đầu chuyển sang hash theo file phải khởi tạo checkpoint bằng xử lý lại file liên quan, không chỉ đánh dấu trạng thái bằng tay.
### 3.6.2 Nạp và cập nhật dimension
Loader dimension lấy #DeltaTrip từ các file cần xử lý để tìm mã nghiệp vụ mới. Các danh mục nhỏ như Taxi Zone được đọc riêng để cập nhật Type 1; các nhóm mã service, vendor, rate code, payment, trip type, provider và base được tra theo quy tắc tương ứng. Việc này tránh quét toàn bộ lịch sử chuyến để thêm một mã mới mỗi lượt nạp.

Dimension cần được nạp trước fact để các khóa ngoại đã có đích tham chiếu. Dòng Unknown được kiểm tra và giữ ổn định. Các fingerprint mapping theo nhóm Location, Base và nhóm mã khác được dùng để xác định khi nào file còn mã chưa giải quyết cần được chọn lại.
### 3.6.3 Tra cứu khóa và xử lý Unknown
Mỗi mã nguồn được lookup vào dimension đúng vai trò. Pickup và Dropoff cùng tra Location nhưng ghi vào hai khóa khác nhau; Request và On Scene cũng tra ngày giờ riêng. Null nguồn đi theo trạng thái chưa biết hoặc không áp dụng đã định nghĩa; mã có giá trị nhưng chưa tra được được ghi nhận vào UnresolvedMask để hỗ trợ xử lý khi mapping thay đổi.

Không được dùng một mã như LocationID trực tiếp làm LocationKey nếu hai miền khóa chưa được bảo đảm đồng nhất. UnknownMask không phải lý do xóa chuyến khỏi tổng; đó là dấu vết chất lượng và phụ thuộc mapping. Sau khi nạp, khóa ngoại vẫn phải hợp lệ dù ngữ nghĩa một số thuộc tính còn chưa biết.
### 3.6.4 Nạp các fact giao dịch
Mỗi task fact lấy file pending của dataset tương ứng, dựng #Desired từ clean.ValidTrip của một file và lookup đầy đủ các khóa. Tập mong đợi được so với fact hiện có theo hash và lineage. Các thao tác audit, delete, update, insert, kiểm tra số dòng và checkpoint thành công nằm trong transaction theo file.

YellowGreen ghi ServiceTypeKey để tách hai nguồn; FHV ghi các vai trò base và FHVFlagKey; HVFHV ghi provider, các mốc thời gian và cờ chuyên biệt. File không có dòng hợp lệ vẫn phải đồng bộ thành tập fact rỗng trong phạm vi file đó, thay vì bỏ qua và để lại các dòng hợp lệ của phiên bản cũ.
### 3.6.5 Xử lý file hiệu chỉnh và bản ghi trùng
Hash payload chứa ngữ cảnh nguồn và file; ordinal phân biệt các lượt xuất hiện có nội dung giống nhau trong cùng file. Cách này bảo toàn multiplicity: hai dòng giống nhau không mặc nhiên là lỗi trùng cần loại. Đồng thời việc một dòng giống nội dung xuất hiện ở file khác không làm checkpoint của hai file ảnh hưởng nhau.

Khi nguồn hiệu chỉnh, tập #Desired có thể khác tập fact hiện tại. Loader ghi audit trước khi xóa phần không còn phù hợp và bổ sung nội dung mới. Một correction có thể làm TripKey thay đổi; người vận hành phải theo lineage và audit để truy vết. Thiếu stable TripID nguồn là giới hạn thiết kế cần được công bố, không được che bằng cách gọi RecordHash là mã chuyến chính thức.
### 3.6.6 Quản lý transaction và checkpoint
Transaction theo file bảo đảm dữ liệu fact và checkpoint thành công cùng commit hoặc cùng rollback. Nếu file thứ ba lỗi, hai file trước đã commit vẫn được giữ; khi chạy lại, checkpoint cho phép chỉ chọn phần cần xử lý. Run tổng không phải một transaction bao phủ mọi file và mọi công nghệ.

DwhFileLog ghi dataset, SourceKey, phiên bản nguồn và loader, trạng thái, ForceReload, số dòng valid và fact, số insert update delete, UnknownMask và lỗi. Các session context hỗ trợ thử lỗi trước checkpoint trong fixture. FAILED được chọn lại theo quy trình; không sửa Status thành SUCCEEDED để vượt qua validation.
### 3.6.7 Đối soát sau khi nạp
Validation theo lượt kiểm tra coverage checkpoint và số dòng của các file cần xử lý. Full reconciliation là kiểm tra riêng trên toàn kho khi không có ETL chạy, hỗ trợ phát hiện sửa đổi ngoài pipeline hoặc checkpoint không còn phản ánh fact. Hai cấp kiểm tra bổ sung nhau và không nên coi đếm tổng bằng nhau là chứng minh mọi thuộc tính đúng.

Một file có đúng số dòng nhưng lookup sai provider hoặc công thức tiền sai vẫn có thể vượt đối soát count. Do đó fixture cần kiểm tra payload, mapping và correction; khóa ngoại kiểm tra tham chiếu; SQL MDX kiểm tra sự thống nhất tầng phân tích. Báo cáo giữ riêng từng loại bằng chứng để không phóng đại phạm vi kiểm thử.
## 3.7 Xây dựng luồng tổng hợp dữ liệu
### 3.7.1 Tổng hợp tài chính theo ngày
Daily Financial nhóm các transaction có tài chính theo DateKey và ServiceTypeKey. Đầu ra gồm TotalTrips, TotalDistanceMiles, TotalPassengerCharges, TotalTips, TotalTaxesAndFees và TotalDriverPay. Cách xây từng khoản dựa trên khả năng nguồn: tiền tài xế chủ yếu có ở HVFHV, trong khi TotalAmount của taxi là giá trị nguồn riêng.

Không nối FHV vào với các cột tiền bằng 0 và không cộng lặp cước cơ bản vào tổng tiền đã bao gồm cước. Các giá trị thiếu cần được giữ để người đọc hiểu độ bao phủ tài chính. Kiểm tra tổng snapshot so với phép nhóm SQL nguồn là điều kiện trước commit.
### 3.7.2 Tổng hợp lưu lượng theo vùng
Zone Traffic tạo một tập pickup theo khóa ngày giờ vùng đón và một tập dropoff theo khóa ngày giờ vùng trả. Hai tập được kết hợp rồi group ở grain ngày, phút, vùng, dịch vụ. Unknown vẫn nằm trong tổng hợp để không làm mất lượng chuyến chưa có địa lý.

So sánh nguồn được thực hiện trên cùng sự kiện. Nếu hỏi nhu cầu đón tại quận, dùng TotalPickups và ngày pickup; nếu hỏi nơi kết thúc, dùng TotalDropoffs và ngày dropoff. Không dùng hai đại lượng cộng lại để báo cáo số chuyến, và không ép chúng bằng nhau ở từng ngày hoặc từng zone.
### 3.7.3 Tổng hợp hiệu suất điều phối
Base Performance nhóm theo ngày, dispatch base, dịch vụ và provider. Thời lượng và chờ được cộng cùng các số đếm hợp lệ tương ứng. Các tổng request, match, WAV và tiền tài xế giữ riêng để phục vụ các công thức đã định nghĩa ở tầng SSAS.

AverageTripDurationSeconds và AverageWaitingTimeSeconds ở một dòng snapshot chỉ diễn tả nhóm grain đó. Khi người dùng chọn nhiều base hoặc nhiều ngày, SSAS phải dùng TotalTripDurationSeconds chia DurationTripCount, hoặc TotalWaitingTimeSeconds chia WaitingTripCount, rồi đổi đơn vị. Lấy trung bình các giá trị trung bình sẽ sai khi số chuyến mỗi nhóm khác nhau.
### 3.7.4 Kiểm tra tính nhất quán của các bảng tổng hợp
Ba snapshot và watermark được rebuild trong cùng một transaction, gồm cả validation. Nếu một phép kiểm tra thất bại, các bảng tổng hợp và watermark cùng rollback. Điều này tránh trạng thái Daily Financial đã mới nhưng Zone Traffic vẫn cũ trong một lần aggregate được xem là thành công.

Thiết kế hiện rebuild toàn bộ, có lợi cho phản ánh correction và deletion lịch sử nhưng chưa tối ưu theo ngày bị ảnh hưởng. Watermark không được mô tả như bằng chứng aggregate đã incremental theo vùng thay đổi. Khi dữ liệu tăng, có thể thiết kế phạm vi tổng hợp lại dựa trên lineage, nhưng phải giữ tính nguyên tử và kiểm tra tổng.
## 3.8 Xử lý lỗi và vận hành
### 3.8.1 Nhật ký và theo dõi tiến trình
PipelineRun ghi RunId, ConfigHash, khoảng tháng, giới hạn dòng, trạng thái, thời điểm và lỗi cấp lượt. PipelineStep ghi stage, task, thời gian, trạng thái và thống kê. PackageError ghi lỗi native SSIS khi handler hoạt động; runner còn giữ events.jsonl, status.json, failure JSON, stdout và stderr để không phụ thuộc hoàn toàn vào SQL.

Monitor hiển thị stage, task hoặc file, số dòng wrk, thời gian và heartbeat. Các câu SQL không cung cấp phần trăm hoàn tất nên monitor không tự tạo phần trăm giả. Một khoảng thiếu heartbeat chưa đủ để khẳng định tiến trình chết vì một số thao tác đồng bộ có thể vẫn đang làm việc; cần kiểm tra cả process, khóa SQL và log trước khi phục hồi.
### 3.8.2 Cách ly file lỗi
Quarantine sao chép CSV, sidecar và error JSON vào thư mục theo RunId và dataset khi file không đáp ứng inspect, bulk hoặc commit. Lỗi gốc được giữ và luồng dừng. Đây là cách ly lỗi cấp file; bản ghi lỗi nghiệp vụ có cấu trúc hợp lệ được phản ánh trong clean.RejectedTrip hoặc clean.WarningTrip, không nhất thiết nằm trong quarantine.

Alert JSON được tạo cho công cụ giám sát đọc khi run thất bại. Hệ thống không mặc nhiên đã gửi email hoặc thông báo ra ngoài. Xử lý lỗi cần dựa vào file, stage và InvocationId đúng, tránh dùng một alert cũ làm kết luận cho lần retry hiện tại.
### 3.8.3 Retry chạy lại và phục hồi
Controller cho retry tối đa theo pMaxRetries trong khoảng 0 đến 3, mặc định 1. Chỉ các lỗi SQL tạm thời được nhận diện như timeout, deadlock và một số lỗi kết nối mới đủ điều kiện; lỗi schema, dữ liệu hoặc Python không tự retry như lỗi mạng. Structured failure giữ SqlNumber qua tiến trình con và kiểm tra InvocationId để tránh đọc nhầm lỗi cũ.

Resume yêu cầu RunId cũ, cấu hình khớp và stage trước đã StageComplete SUCCEEDED. Stage lỗi chạy lại theo checkpoint của chính nó, không tiếp tục giữa một câu SQL. Controller đã dùng Job Object KILL_ON_JOB_CLOSE để quản lý runner và hậu duệ; Recover-Run chỉ đóng run RUNNING thành FAILED theo thao tác chủ động khi lấy được khóa độc quyền. Chưa có trạng thái CANCELLED hoặc ABANDONED tự động và chưa có nút hủy trên monitor.
### 3.8.4 Kiểm soát chạy đồng thời
Runner giữ sp_getapplock độc quyền với tài nguyên NYCTaxi Full Pipeline theo session và không chờ khi có khóa khác. Ngoài khóa đang giữ, run RUNNING chưa kết thúc cũng chặn một RunId mới. Hai cơ chế bảo vệ ngăn việc chạy chồng do lịch hoặc do người dùng khởi chạy thêm.

Các đường native package con chưa được xác nhận dùng đầy đủ cùng guard. Vì vậy quy trình vận hành thống nhất qua Master hoặc runner; không Execute package con song song. Không tạo RunId mới hoặc sửa log để vượt guard khi chưa kiểm tra tiến trình cũ đã dừng và khóa đã được giải phóng.
### 3.8.5 Lập lịch thực thi
Hồ sơ hardening ghi đã đăng ký task NYCTaxi Monthly ETL chạy ngày 15 hàng tháng lúc 10 giờ Bangkok, chọn tháng hiện tại trừ hai và MaxRows 100000. Tháng mục tiêu được tính lúc chạy, không cố định theo ngày đăng ký. Task dùng interactive token nên người dùng phải đăng nhập; StartWhenAvailable không thay thế điều kiện này.

Cấu hình có IgnoreNew và giới hạn thời gian 24 giờ. Mặc định script đăng ký là MaxRows 0, khác giá trị đã truyền khi tạo lịch trong hồ sơ. Chưa có bằng chứng chạy thử lịch thật sau đăng ký; vì vậy báo cáo xác nhận có cấu hình lịch nhưng không kết luận lịch đã vận hành tự động ổn định. Lịch có thể nhận lại tháng cũ nhưng không tự giải quyết mọi file hiệu chỉnh ngoài phạm vi được chọn.
## 3.9 Kiểm thử và đánh giá kết quả ETL
Hồ sơ rà soát ghi 56 file chuyến được đối chiếu clean fact không lệch số dòng; transaction fact gồm 278.213 YellowGreen, 139.970 FHV và 140.000 HVFHV, tổng 558.183. Lượt no-op được chụp có PendingFiles bằng 0 và cả ba task fact ProcessedFiles bằng 0. Đây là bằng chứng DWH bỏ qua file không đổi trong lần quan sát, không chứng minh Transform, Aggregate và SSAS đều incremental.

Hồ sơ hardening ghi 12 trên 12 kiểm thử Python và metadata, 22 trên 22 ca SQL incremental cách ly, ba ca mapping cờ FHV, bảy ca controller cùng các kiểm tra Job Object và truyền lỗi. Fixture cách ly không phải benchmark full data. Sau thay đổi loader FHV, cần chạy production có kiểm soát và đối soát theo đúng phiên bản trước khi coi chuyển đổi hoàn tất.
@testsummary

# CHƯƠNG 4 XÂY DỰNG MÔ HÌNH PHÂN TÍCH SSAS
## 4.1 Mục tiêu và tổ chức mô hình SSAS
SSAS tạo tầng ngữ nghĩa đa chiều để các báo cáo dùng chung khóa phân tích và công thức. Dự án dùng sáu cube nghiệp vụ, mỗi cube một measure group gắn với fact tương ứng. Các database dimension và DSV được dùng chung; cube chỉ tham gia các dimension phù hợp với phạm vi nghiệp vụ.

Cách tổ chức này làm rõ nguồn của từng phép đo. Một card Trip Count của FHV không phải tổng mọi dịch vụ, còn Daily Financial không bao gồm FHV tài chính. Không có một measure mặc định cộng chéo sáu cube; người đọc phải dùng cùng phạm vi lọc hoặc snapshot phù hợp cho câu hỏi liên nguồn.
## 4.2 Khởi tạo Data Source và Data Source View
Data Source DS_NYCTaxi_DWH dùng provider MSOLEDBSQL để đọc NYCTaxi_DWH trên SQL Server cấu hình. Windows authentication và danh tính dịch vụ SSAS quyết định quyền truy cập trong lúc process. Đúng connection string nhưng thiếu quyền SELECT vẫn làm xử lý dữ liệu thất bại.

DSV mô tả 15 dimension, ba fact giao dịch và ba snapshot cùng quan hệ khóa. Tệp DSV_NYCTaxi.dsv giữ tên kế thừa, còn ID mô hình là DSV_NYCTaxi_DWH. DSV cũ NYC Taxi DWH được giữ trên đĩa nhưng không dùng làm DSV hoạt động của project. Khi triển khai phải đối chiếu ID tham chiếu trong cube thay vì chọn một file chỉ vì tên gần giống.
@figure ssas
## 4.3 Xây dựng các dimension phân tích
### 4.3.1 Cấu hình thuộc tính khóa và tên hiển thị
Mỗi dimension khai báo KeyColumns xác định member, NameColumn xác định nhãn và thuộc tính phục vụ lọc. Tên hiển thị trùng không chứng minh hai member là một; vùng dùng LocationKey làm khóa nhưng hiển thị ZoneName. Mã nghiệp vụ và nhãn cũng được tách ở provider, base và các chiều phân loại.

Các thuộc tính nullable có quy tắc chuyển lỗi hoặc blank riêng ở tầng phân tích. Không mở rộng quy tắc attribute NULL thành một nguyên tắc thay toàn bộ measure NULL bằng 0. Tập dimension được xử lý trước hoặc cùng batch xử lý cube để các tham chiếu member luôn sẵn sàng.
@dimensionattributes
### 4.3.2 Xây dựng hierarchy và quan hệ thuộc tính
Calendar gồm Year, Quarter, Month và Date; Geography gồm Borough và Zone; Time gồm TimeBand, Hour và Time. Key ghép theo năm giúp thứ tự thời gian đúng ở nhiều năm. NameColumn hỗ trợ nhãn đọc được, còn quan hệ thuộc tính mô tả các phụ thuộc tự nhiên để SSAS tổng hợp và điều hướng.

Một hierarchy có tên và thứ tự cấp chưa đủ nếu attribute key hoặc relationship sai. Cần kiểm tra mỗi ngày chỉ thuộc một tháng và năm đúng, mỗi zone thuộc Borough theo danh mục, và Unknown không bị gộp với giờ 0. Các hierarchy này cũng định hướng cách bố trí drill và bộ lọc trên Power BI.
### 4.3.3 Cấu hình dimension đóng nhiều vai trò
Ở cube, cùng database dimension được đưa vào các role có ID riêng như Pickup Date, Dropoff Date, Request Date hoặc On Scene Time. Dimension Usage nối từng role về cột khóa tương ứng của measure group. Đó là cách giữ một danh mục chuẩn trong khi vẫn cho phép lọc theo nhiều mốc độc lập.

Lọc Pickup Date trả lời các chuyến bắt đầu trong ngày, còn lọc Dropoff Date trả lời các chuyến kết thúc trong ngày. Nếu đặt cả hai, kết quả là giao của hai điều kiện chứ không phải hai cách gọi cho một trường. Dashboard phải chọn role phù hợp với câu hỏi; snapshot sử dụng role Snapshot Date theo grain tổng hợp.
### 4.3.4 Xử lý Unknown và lỗi khóa
Dimension giữ member khóa 0 như dữ liệu thông thường, đồng thời có UnknownMember bổ sung cho khóa không phân giải. ErrorConfiguration đặt KeyNotFound, KeyDuplicate và NullKeyNotAllowed theo hướng ReportAndStop. Lỗi tham chiếu không được che bằng cách bỏ fact hoặc tăng ErrorLimit để làm trạng thái Processed xuất hiện.

Khi process lỗi, cần đối chiếu khóa nguồn, DSV, dimension và fact trước khi thử lại. Việc có nhóm Unknown trên báo cáo không tự chứng minh process sai: đó có thể là kết quả loader giữ đúng sự kiện thiếu thuộc tính. Ngược lại, không nhìn thấy Unknown chưa chắc dữ liệu hoàn chỉnh nếu visual đã lọc bỏ nhóm này.
## 4.4 Xây dựng các cube nghiệp vụ
### 4.4.1 Cube YellowGreen Trips
Cube sử dụng Fact_YellowGreen_Trips và các vai trò ngày giờ vùng đón trả, cùng Service Type, Vendor, Rate Code, Payment Type, Trip Type, Taxi Flags, Passenger Group và Load Batch. Các measure tài chính, quãng đường và số chuyến chỉ áp dụng phạm vi YellowGreen. Service Type cho phép tách Yellow và Green trong cùng một bề mặt phân tích.

Calculated measure tính trung bình cước, khoảng cách, thời lượng, tip và tốc độ từ các tổng hoặc mẫu số hỗ trợ. Đối với tỷ lệ tip, mẫu số là cước cơ bản ở cùng tập có cả tip và cước, không phải TotalAmount. Measure hỗ trợ được ẩn khỏi danh sách nghiệp vụ khi không cần cho người sử dụng cuối.
@cube YellowGreen_Trips
### 4.4.2 Cube FHV Trips
Cube FHV dùng fact FHV để phân tích Trip Count và Trip Duration Seconds, cùng trung bình thời lượng tính từ mẫu số hợp lệ. Dispatch Base và Affiliated Base là các role riêng. Cube không được bổ sung measure tiền hoặc quãng đường không có trong nguồn chỉ để đồng nhất danh sách với YellowGreen.

Các phân tích địa lý phải giữ giới hạn Unknown; các phân tích theo tháng dùng Calendar của đúng role. Khi giải thích thời lượng, cần nêu measure gốc là giây và calculated measure đổi sang phút. Đơn vị là một phần của định nghĩa, không chỉ là chuỗi định dạng trên visual.
@cube FHV_Trips
### 4.4.3 Cube HVFHV Trips
Cube HVFHV sử dụng các role thời gian Request, On Scene, Pickup, Dropoff cùng địa lý, provider, base và cờ HVFHV. Các measure tài chính gồm cước cơ bản, phí, thuế, tip, tiền tài xế và tổng tiền khách theo DWH. Nhóm thời gian chờ có mẫu số hợp lệ riêng vì không phải mọi dòng đều có request phù hợp.

Average Waiting Minutes lấy tổng WaitingTimeSeconds chia số dòng có giá trị hợp lệ rồi đổi phút. On Scene To Pickup Seconds là một đại lượng khác và có giới hạn độ bao phủ của nguồn. Tốc độ dùng cùng tập dòng có quãng đường hợp lệ và thời lượng dương. Không chia tổng quãng đường của mọi dòng cho thời gian chỉ của một phần khác.
@cube HVFHV_Trips
### 4.4.4 Cube Daily Financial
Cube Daily Financial đọc snapshot ngày và dịch vụ, dùng các measure tổng tài chính được ETL chuẩn bị. Điều này giúp báo cáo tài chính không phải quét và phối hợp ba transaction fact ở lớp Power BI. Snapshot Date và Service Type xác định phạm vi chính; các chiều thanh toán hoặc provider không được tự gán nếu không có trong grain.

Các ô tiền tài xế thiếu không được hiểu là doanh nghiệp không trả tiền; đó có thể là trường không áp dụng cho nguồn. Daily Financial phục vụ mô tả dòng tiền ghi nhận, chưa phải báo cáo kết quả kinh doanh đầy đủ. Không thêm tổng số chuyến của cube này vào số chuyến transaction.
@cube Daily_Financial
### 4.4.5 Cube Zone Traffic
Cube Zone Traffic đọc snapshot ngày, phút, vùng và dịch vụ, cung cấp TotalPickups và TotalDropoffs. Đây là bề mặt phù hợp để so lưu lượng các dịch vụ theo cùng tập chiều chung. Khi roll up qua giờ hoặc Borough, SSAS cộng các sự kiện thuộc các member ở cấp thấp hơn.

Measure có ý nghĩa theo loại sự kiện nên tiêu đề visual phải ghi rõ lượt đón hoặc lượt trả. Không gọi một visual TotalDropoffs là nhu cầu đón. Trường hợp so sánh nhiều nguồn vẫn cần kiểm tra các file của mỗi nguồn có giới hạn hoặc độ bao phủ tương đương hay không.
@cube Zone_Traffic
### 4.4.6 Cube Base Performance
Cube Base Performance đọc snapshot ngày, dispatch base, dịch vụ và provider. Ngoài tổng chuyến và tiền tài xế, cube lưu các tổng thời lượng và số đếm hợp lệ làm cơ sở tính trung bình. Shared Request Rate chỉ có ý nghĩa ở phạm vi dịch vụ có cờ yêu cầu đi chung.

WAV Match Rate đã được ẩn trong MDX script của bản hardening do phép chia hai tổng chưa có nghĩa tỷ lệ đáp ứng yêu cầu. Các measure số đếm vẫn giữ nguyên. Ẩn chỉ số là kiểm soát ngữ nghĩa sử dụng, không phải sửa dữ liệu để đưa kết quả về dưới 100 phần trăm.
@cube Base_Performance
## 4.5 Thiết kế measure và calculated measure
### 4.5.1 Các độ đo cộng dồn
Measure cộng dồn dùng hàm Sum trên các cột số đếm, khoảng cách, thời gian và tiền ở đúng fact. Giá trị thời gian dùng giây ở measure gốc; khoảng cách dùng mile; tiền dùng USD. Cột AverageSpeedMPH hay AverageTripDurationSeconds không được đưa thành Sum để mô tả tốc độ hoặc thời lượng trung bình của tổng thể.

Các measure hỗ trợ như ValidTrips, TipPairAmount, TipPairFare và các tổng cho tập tính tốc độ được DSV hoặc mô hình dùng để bảo đảm cùng tập tử mẫu. Chúng có thể bị ẩn vì phục vụ công thức, nhưng vẫn là thành phần quan trọng của thiết kế tính đúng.
### 4.5.2 Các độ đo trung bình
Trung bình một measure bằng tổng giá trị chia tổng số dòng có giá trị hợp lệ tương ứng. Ví dụ 10 chuyến có 2 chuyến thiếu quãng đường thì trung bình khoảng cách dùng 8 chuyến, không dùng 10 và cũng không coi 2 dòng thiếu là 0. Khi roll up, SSAS cộng tử và mẫu trước khi chia, tránh trung bình các nhóm có kích thước khác nhau.

Với thời lượng và chờ, chia thêm 60 để đổi giây sang phút sau phép chia có kiểm soát. Với tốc độ, dùng tổng mile nhân 3600 chia tổng giây trên cùng tập dòng hợp lệ. Một mẫu số trống hoặc bằng 0 trả NULL để visual thể hiện không có kết quả, không tạo giá trị vô hạn hoặc 0 giả.
### 4.5.3 Các tỷ lệ nghiệp vụ
Tip Percentage của taxi sử dụng TipAmount trên FareAmount, của HVFHV sử dụng TipAmount trên BasePassengerFare, đều ở tập dòng có đủ hai giá trị. Shared Request Rate dùng số yêu cầu đi chung trên số chuyến thuộc phạm vi nguồn phù hợp. Tỷ lệ phải có tên phản ánh đúng sự kiện và mẫu số, không thể chỉ chọn hai tổng có sẵn rồi gọi là hiệu quả.

Các công thức MDX đầy đủ được lưu trong Phụ lục A; bảng dưới trình bày quy tắc nghiệp vụ để người đọc kiểm tra trước khi xem mã. Việc SQL và MDX trả cùng một giá trị chỉ chứng minh hai tầng nhất quán với nhau; công thức vẫn cần phù hợp định nghĩa nghiệp vụ.
@formulas
### 4.5.4 Xử lý NULL mẫu số bằng không và phạm vi áp dụng
Công thức dùng kiểm tra tập rỗng hoặc mẫu số 0 để trả NULL. Không dùng một giá trị thay thế chung cho mọi trường vì thiếu tiền, không áp dụng và không có giao dịch là các trạng thái khác nhau. Trong biểu đồ, cần diễn giải ô trống theo measure và nguồn, không suy đoán doanh thu bằng 0.

IgnoreUnrelatedDimensions bằng false giúp không lặp một tổng không liên quan theo các member của chiều khác. Payment Type không phải chiều chung của FHV hoặc HVFHV. Mọi so sánh liên cube phải giữ cùng bộ lọc và xác nhận độ bao phủ; chỉ có quan hệ dimension dùng chung không đủ để mọi measure đều so sánh trực tiếp.
## 4.6 Cấu hình Dimension Usage
Dimension Usage xác định role dimension nối tới measure group qua cột khóa nào và attribute granularity nào. Quan hệ Regular được dùng khi khóa dimension nằm trong fact hoặc nguồn của measure group. Một role đúng tên nhưng nối nhầm PickupDateKey và DropoffDateKey có thể tạo báo cáo hợp lệ kỹ thuật nhưng sai câu hỏi nghiệp vụ.

Các bảng Dimension Usage được trình bày cùng từng cube ở mục 4.4. Khi kiểm tra, cần đối chiếu ba tầng: role trong cube, granularity attribute của dimension và cột nguồn trong measure group. Các chiều không nằm trong grain snapshot không được thêm tùy ý chỉ để có thêm slicer.
## 4.7 Thiết kế partition lưu trữ và aggregation
Dự án cấu hình 45 partition MOLAP: 13 FHV, 13 HVFHV, 16 YellowGreen và ba partition snapshot. Các transaction partition phân theo khoảng khóa ngày và nguồn khi cần; Other Dates giữ phần còn lại và Unknown. Tệp partitions có thể lưu State Unprocessed ở source thiết kế, khác trạng thái Processed trên server ở một lần chụp bằng chứng.

QueryDefinition của các partition phải không chồng phạm vi. Khi tách tháng mới, tháng đó phải được loại khỏi catch all để không cộng trùng. Aggregation design Operational chọn các tổ hợp như tháng và dịch vụ, ngày và Borough tùy cube; đây là tối ưu lưu trữ SSAS, khác với ba snapshot do ETL dựng. Planner sinh refresh theo partition đã có, nhưng runner hiện vẫn ProcessFull toàn database.
@partitions
## 4.8 Triển khai và xử lý mô hình
Triển khai lần đầu tạo database mô hình; cập nhật mô hình thay metadata có thể làm mất trạng thái process. Hồ sơ dự án ghi build Visual Studio gặp Invalid license data, còn AMO đã kiểm tra, serialize XMLA và triển khai mô hình. Vì vậy không mô tả một lần build Visual Studio thành công nếu bằng chứng chỉ xác nhận đường AMO và XMLA.

Trong pipeline, runner xác nhận đúng Data Source, SQL database và đủ sáu cube, sau đó dùng XMLA Batch Transaction true để ProcessFull database. Kết quả phải không có XmlaError và database trở lại Processed, rồi mới chạy đối soát SQL MDX. DWH không rollback cùng SSAS nếu bước này lỗi; có thể resume bước cuối khi các điều kiện trước vẫn đúng.
## 4.9 Truy vấn MDX và đối soát với kho dữ liệu
Các truy vấn MDX kiểm tra số chuyến, tổng measure, lát cắt thời gian, địa lý và các công thức nghiệp vụ; SQL tính kết quả tương ứng từ DWH. Chọn Scope Full khi cube đã process toàn kho, không sử dụng test tháng như một bộ lọc tự động cho cube đầy đủ. Trong lúc đối soát cần giữ nguồn ổn định để hai tầng không ở hai thời điểm dữ liệu khác nhau.

Bằng chứng ngày 31 tháng 10 ghi sáu Browse MDX đạt và 102 phép đối soát SQL MDX không thất bại, cùng 15 dimension và 45 partition Processed tại thời điểm chụp. Tài liệu khác có trạng thái Unprocessed sau reset ở thời điểm khác, nên trước demo phải kiểm tra lại nguồn hiện tại. Các ví dụ truy vấn, kết quả và giới hạn kiểm tra được trình bày ở Phụ lục B.

# CHƯƠNG 5 XÂY DỰNG DASHBOARD POWER BI
## 5.1 Mục tiêu và yêu cầu của bộ báo cáo
Bộ báo cáo chuyển các câu hỏi nghiệp vụ thành card, biểu đồ xu hướng, phân bố và bảng chi tiết theo từng cube. Yêu cầu đầu tiên là tên chỉ tiêu và đơn vị rõ ràng; tiếp theo là chọn đúng role ngày hoặc vùng, giữ Unknown và cho phép nhìn phạm vi lọc. Mục tiêu không phải đặt tất cả measure vào một trang mà là giúp trả lời từng nhóm câu hỏi có dữ liệu phù hợp.

Dự án có sáu project PBIP với chín trang theo danh mục source. Một số nhóm nghiệp vụ dùng hai trang, chẳng hạn YellowGreen và HVFHV. Các câu hỏi phân tích tám nhóm trong mục 5.4 được ánh xạ vào những trang hiện có, không tạo thêm một trang chỉ vì mục lục có tám tiêu đề.
@reportindex
## 5.2 Kết nối Power BI với SSAS
Power BI sử dụng Live Connection đến SSAS Multidimensional, database NYCTaxi_SSAS và cube theo project. Model reference dùng connectionType analysisServicesDatabaseLive, Windows SSPI và tên cube tương ứng. Không chọn Import hoặc chuyển sang local model nếu muốn giữ đúng kiến trúc hiện có.

Tệp .pbip cần đi cùng các thư mục .Report và .SemanticModel. Refresh Power BI yêu cầu kết quả mới từ cube, không chạy ETL hoặc process SSAS. Menu mở nhanh kiểm tra trạng thái và probe chỉ đọc trước khi coi nguồn sẵn sàng. Bộ báo cáo chưa được mô tả như đã publish lên Power BI Service; triển khai Service với live SSAS cần gateway và danh tính phù hợp.
@figure powerbi
## 5.3 Thiết kế bộ lọc bố cục và tương tác
Các trang sử dụng bộ lọc năm, tháng và dịch vụ; tùy nghiệp vụ có thêm Borough, provider, payment type hoặc base. Chọn năm trước tháng để tránh so sánh tháng cùng số ở nhiều năm ngoài ý muốn. Bộ lọc của sáu project độc lập, không tự đồng bộ giữa các cửa sổ Power BI.

Card dùng cho tổng hoặc chỉ tiêu chính, biểu đồ đường thể hiện diễn biến, cột so sánh nhóm, ma trận thể hiện kết hợp chiều và bảng hỗ trợ truy vết chi tiết. Field binding phải dùng member và grouping key theo metadata CSDL mà SSAS công bố. Tiêu đề cần ghi rõ USD, mile, giây hay phút; không dựa riêng vào màu hoặc vị trí để truyền đạt ý nghĩa.

Tương tác chọn điểm và slicer phải được kiểm tra bằng Desktop, vì query hợp lệ không chứng minh cross filter hoặc bố cục đã đúng. Khi nguồn rỗng hay Unknown, visual phải phản ánh trạng thái dữ liệu thay vì được lọc để làm kết quả đẹp hơn. Các cấu hình title, filter, sort, query role và kích thước hiện có được liệt kê theo từng trang dưới đây.
## 5.4 Xây dựng các trang phân tích
### 5.4.1 Phân tích hoạt động taxi Yellow và Green
Trang Taxi truyền thống lấy cube YellowGreen Trips. Các card về số chuyến, tổng tiền và các chỉ tiêu trung bình đi cùng phân bố thời gian, địa lý và dịch vụ. Chọn Service Type để tách Yellow và Green; chọn đúng năm tháng có dữ liệu đã process trước khi so sánh giờ hoặc quận.

Quy trình đọc bắt đầu từ tổng số chuyến trong phạm vi lọc, sau đó xem phân bố theo thời gian và địa lý, cuối cùng kiểm tra các nhóm khác biệt. Nếu kết quả chủ yếu thuộc đầu tháng do giới hạn N dòng đầu, phần nhận xét chỉ mô tả phạm vi đó. Tổng tiền khách và cước cơ bản là hai measure riêng; không đặt cùng tên doanh thu nếu chưa nêu định nghĩa.
@page YellowGreen_Trips taxi_overview
### 5.4.2 Phân tích thanh toán và tiền tip
Trang Hành vi và tiền tip dùng các chiều thanh toán, thời gian, cuối tuần và địa lý của YellowGreen. Tỷ lệ tip sử dụng calculated measure của cube để giữ cùng tập tử mẫu. Không lấy trung bình các tỷ lệ của từng payment type hoặc từng quận để tạo một tỷ lệ toàn nhóm.

Dữ liệu tip tiền mặt không đầy đủ nên không kết luận khách tiền mặt không tip từ giá trị trường tip bằng 0 hoặc thiếu. Bộ lọc payment type giúp mô tả phần ghi nhận trong hệ thống, không tự tạo một nghiên cứu hành vi toàn bộ hành khách. Nhận xét cần nêu loại thanh toán, thời gian và dịch vụ đã lọc.
@page YellowGreen_Trips taxi_tips
### 5.4.3 Phân tích hoạt động xe công nghệ
Trang Xe công nghệ dùng HVFHV Trips, tập trung lượng chuyến, quãng đường, thời lượng, chờ và provider. Các phân tích theo Borough cần dùng đúng Pickup Location cho câu hỏi nhu cầu đón. Khi so sánh provider, bộ lọc thời gian và độ bao phủ nguồn phải giống nhau để tránh khác biệt do phạm vi nạp.

Chỉ tiêu Average Waiting Minutes mô tả từ request đến pickup theo định nghĩa loader và tập hợp lệ. Không đổi tên thành thời gian xe đến nơi khi chưa dùng đúng mốc on scene. Chênh lệch giữa hai provider hoặc quận trong tập mẫu chỉ là quan sát mô tả, chưa loại trừ khác biệt về khu vực, thời điểm hay cơ cấu chuyến.
@page HVFHV_Trips hvfhv_overview
### 5.4.4 Phân tích phí và thu nhập
Trang Phí và thu nhập tách cước cơ bản, tổng tiền khách, thuế phí, tip và tiền tài xế. Việc đặt các series cạnh nhau giúp thấy cơ cấu và biến động nhưng không cho phép gọi chênh lệch là lợi nhuận ròng. Driver pay theo nguồn không đồng nghĩa số tiền tài xế mang về sau mọi chi phí vận hành cá nhân.

Phân tích phí theo tháng hoặc dịch vụ phải tính đến thời kỳ xuất hiện trường CBD và phạm vi file. Một biểu đồ có phí tăng và số chuyến giảm không đủ để kết luận quan hệ nhân quả. Muốn đánh giá tác động chính sách cần dữ liệu đầy đủ, thiết kế trước sau và các biến kiểm soát bổ sung.
@page HVFHV_Trips hvfhv_fees
### 5.4.5 Phân tích hoạt động FHV
Trang FHV truyền thống trình bày số chuyến, thời lượng và phân bố theo thời gian, quận hoặc base. Số liệu tài chính không nằm trong phạm vi trang vì nguồn FHV hiện dùng không có các trường đó. Tổng thời lượng gốc có thể dùng giây trong khi trung bình dùng phút, nên mỗi card phải theo tên và định dạng cụ thể.

Một base có nhiều chuyến chưa chắc có chất lượng phục vụ cao hơn nếu chưa có tiêu chí về chờ, địa bàn hoặc loại chuyến. Vị trí Unknown làm hạn chế phân tích địa lý, cần giữ trong bảng hoặc tổng để người đọc thấy độ bao phủ. Cờ FHV cần được đọc theo phiên bản loader đã process, nhất là sau bản sửa SourceSRFlag.
@page FHV_Trips *
### 5.4.6 Phân tích tài chính theo ngày
Trang Tài chính theo ngày sử dụng Daily Financial để theo dõi các tổng ở grain ngày và dịch vụ. Chọn cùng năm tháng và Service Type trước khi đối chiếu tổng tiền khách, tip, thuế phí và tiền tài xế. FHV không thuộc nguồn tài chính của snapshot nên không suy ra giá trị thiếu là 0 USD.

Trang này hỗ trợ xem quy mô và diễn biến tài chính ghi nhận. Nếu cần giải thích sự thay đổi do số chuyến hay giá trị mỗi chuyến, phải kết hợp số chuyến cùng phạm vi và công thức trung bình hợp lệ, không chỉ so độ cao hai đường. Các tổng snapshot được đối chiếu với fact nguồn tại bước aggregate và SQL MDX.
@page Daily_Financial *
### 5.4.7 Phân tích nhu cầu theo khu vực và khung giờ
Zone Traffic có trang Nhu cầu theo khu vực và trang chi tiết không gian giờ. TotalPickups và TotalDropoffs hỗ trợ so phân bố sự kiện theo vùng, dịch vụ, giờ và ngày. Ma trận Borough với giờ giúp xem vị trí tập trung trong tập nạp; drill xuống Zone cần giữ đúng hierarchy và grain.

Đón và trả là hai loại sự kiện khác nhau của một chuyến, có thể nằm ngoài cùng ngày. Một vùng trả nhiều hơn đón trong ngày không có nghĩa lỗi tính tổng. Khi so các dịch vụ, cần nêu số file và giới hạn dòng để không gọi tỷ trọng trong sample là thị phần New York.
@page Zone_Traffic *
### 5.4.8 Phân tích hiệu suất điều phối
Trang Hiệu suất điều phối dùng Base Performance để xem khối lượng, thời lượng, thời gian chờ và yêu cầu đi chung theo dispatch base, provider và dịch vụ. Trung bình sử dụng measure của cube tính từ tổng và số đếm hợp lệ; không dùng average của các giá trị trung bình đã hiển thị theo base.

Khi drill hoặc chọn một base, phải phân biệt mã base với giấy phép provider. Shared Request Rate mô tả yêu cầu đi chung trong phạm vi có dữ liệu, không phải tỷ lệ ghép thành công. WAV Match Rate không được đưa vào báo cáo vì chưa có định nghĩa tử mẫu phù hợp; không clamp một tỷ lệ vượt 100 phần trăm để tạo kết quả có vẻ hợp lý.
@page Base_Performance *
## 5.5 Khai thác dashboard để trả lời câu hỏi nghiệp vụ
Quy trình khai thác bắt đầu từ câu hỏi, chọn cube hoặc trang đúng phạm vi, xác định bộ lọc và đọc chỉ tiêu cùng đơn vị. Sau khi phát hiện một khác biệt, người dùng drill theo dimension phù hợp rồi đối chiếu card với lát cắt SQL MDX. Kết luận phải ghi rõ khoảng thời gian thực có dữ liệu, dịch vụ, vùng và giới hạn sample.

Ví dụ, để hỏi dịch vụ nào có nhiều lượt đón trong một Borough vào một nhóm giờ, dùng Zone Traffic với TotalPickups, cùng năm tháng và Borough, thay vì mở hai transaction report rồi cộng card có bộ lọc khác nhau. Để hỏi giá trị tip theo thanh toán taxi, dùng YellowGreen và nêu giới hạn tip tiền mặt. Để hỏi chờ theo provider, dùng HVFHV hoặc snapshot base với cùng phạm vi và số dòng chờ hợp lệ.

Trong bằng chứng hiện có, tổng số chuyến FHV và HVFHV lần lượt 139.970 và 140.000 không phải kết luận hai dịch vụ có quy mô thị trường gần bằng nhau: từng file bị giới hạn theo cùng chính sách N dòng đầu. Đây là ví dụ cho thấy kiểm tra độ bao phủ phải đi trước diễn giải kinh doanh. Báo cáo ưu tiên những kết luận mà cấu trúc và phạm vi dữ liệu thực sự hỗ trợ.
## 5.6 Kiểm thử dữ liệu và tương tác trên dashboard
Hồ sơ có 70 field binding duy nhất và 101 truy vấn visual đạt ở thời điểm kiểm tra. Schema validation kiểm tra định nghĩa JSON, còn các truy vấn kiểm tra tên trường, measure và grouping key theo CSDL. Các kiểm tra đó hỗ trợ chất lượng đầu vào của visual, nhưng không thay thế mở chín trang trong Power BI Desktop.

Nghiệm thu giao diện phải kiểm tra kết nối live khi cube Processed, tải tất cả trang, chọn năm tháng dịch vụ, thử các bộ lọc đặc thù, tập rỗng và Unknown, đối chiếu card, kiểm tra đơn vị, sort, drill và tương tác. Mỗi ảnh bằng chứng cần có thời gian và phạm vi lọc. Báo cáo không gắn nhãn đã đạt cho những bước chưa có bằng chứng UI tương ứng.
@dashboardtests
## 5.7 Đánh giá kết quả và giới hạn diễn giải
Bộ báo cáo đã có cấu trúc theo sáu nghiệp vụ, liên kết trực tiếp các cube và có các bằng chứng kiểm tra dữ liệu cùng field binding. Việc tách nguồn và chỉ tiêu giúp tránh nhiều sai lầm thường gặp như cộng trùng snapshot với transaction, dùng chiều thanh toán cho FHV hoặc tính trung bình không đúng mẫu số. Các sơ đồ trong báo cáo là minh họa thiết kế, không được trình bày như ảnh chụp dashboard đã chạy.

Giới hạn còn lại gồm dữ liệu sample theo đầu file, chất lượng vị trí và các mốc nguồn không đồng đều, một số thuộc tính lịch hoặc lịch sử dimension chưa đầy đủ, và kiểm thử Desktop chưa bao phủ toàn bộ trang sau các thay đổi cuối. Các biểu đồ có tính mô tả; chưa chứng minh thị phần toàn thành phố, lợi nhuận doanh nghiệp hay tác động nhân quả. Kết luận sử dụng phải giữ các giới hạn này cùng kết quả số.

# KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN
Đề tài xây dựng chuỗi xử lý NYC Taxi từ dữ liệu file đến báo cáo đa chiều. Kho được thiết kế theo Galaxy Schema với 15 dimension, ba transaction fact và ba snapshot có grain rõ ràng. Pipeline bảo toàn lineage theo file, phân loại chất lượng, hỗ trợ checkpoint và nạp lại khi nguồn thay đổi. SSAS tổ chức sáu cube theo nghiệp vụ và tính các trung bình, tỷ lệ từ tập dữ liệu phù hợp; Power BI cung cấp các trang khai thác tương ứng.

Những bằng chứng lưu trong dự án cho thấy các tập kiểm tra count, khóa ngoại, checkpoint và SQL MDX đã có kết quả nhất quán ở các lần quan sát. Các bản hardening bổ sung mapping FHV, quản lý tiến trình con, truyền lỗi có cấu trúc và lịch tháng. Những kết quả đó cần được phân biệt với kiểm thử production, kiểm thử lịch thật, phục hồi backup và nghiệm thu UI chưa được thực hiện đầy đủ.

Hướng phát triển trước hết là hoàn tất nghiệm thu theo đúng phiên bản, thử phục hồi và thống nhất mọi đường chạy qua guard điều phối. Về tính đúng nghiệp vụ, cần bổ sung lịch ngày lễ đáng tin cậy, xem xét lịch sử thuộc tính base khi có yêu cầu và định nghĩa KPI trên cùng tập tử mẫu. Về hiệu năng, cần đo trên dữ liệu lớn rồi tối ưu Transform theo metadata, aggregate theo ngày bị ảnh hưởng và process partition liên quan, đồng thời giữ đối soát và khả năng phục hồi.

# TÀI LIỆU THAM KHẢO
[1] NYC TLC Trip Record Data. https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page. Đối chiếu nguồn dữ liệu và các liên kết metadata khi biên soạn.

[2] NYC TLC Yellow Taxi Trip Records Data Dictionary. https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf.

[3] NYC TLC Green Taxi Trip Records Data Dictionary. https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_green.pdf.

[4] NYC TLC FHV Trip Records Data Dictionary. https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_fhv.pdf.

[5] NYC TLC High Volume FHV Trip Records Data Dictionary. https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_hvfhs.pdf.

[6] NYC TLC Trip Record User Guide. https://www.nyc.gov/assets/tlc/downloads/pdf/trip_record_user_guide.pdf.

[7] Mã nguồn dự án NYC Taxi: etl/packages, etl/python, các script điều phối, mô hình NYCTaxi_SSAS và định nghĩa powerbi/reports. Các đường dẫn trong chương triển khai phản ánh môi trường source đang lưu.

[8] Metadata và bằng chứng: evidence/columns.json, primary-keys.json, foreign-keys.json, review-20261031/REVIEW.md, final-status.json và reconciliation-Full.csv. Bằng chứng có thời điểm chụp, không phải giám sát liên tục.

[9] Hồ sơ vận hành và cập nhật: etl/README.md, incremental/README.md, hardening/STATUS.md, handover/README.md, powerbi/README.md. Khi có khác biệt lịch sử, dùng source và hồ sơ cập nhật tương ứng phiên bản được mô tả.

# PHỤ LỤC A SQL VÀ CẤU HÌNH KỸ THUẬT CHI TIẾT
Phụ lục lưu đặc tả để đối chiếu với phần giải thích trong các chương. Mã SQL và MDX được trích từ source, không được thực thi trong lần biên soạn. Tham số, đường dẫn và phiên bản phải được kiểm tra trước khi dùng trên một môi trường khác.
@appendixsource

# PHỤ LỤC B TRUY VẤN KIỂM TRA VÀ KẾT QUẢ ĐỐI SOÁT
Các bảng bằng chứng dưới đây là kết quả đã lưu trong dự án. Chúng được dùng để đánh giá phạm vi kiểm chứng của hệ thống, không phải kết quả chạy lại tại ngày biên soạn. Mỗi nhóm kiểm tra có mục đích riêng: đếm dòng, toàn vẹn khóa, trạng thái xử lý hoặc sự nhất quán SQL MDX.
@evidence

# PHỤ LỤC C HƯỚNG DẪN TRIỂN KHAI VÀ VẬN HÀNH
## C.1 Chuẩn bị cấu hình môi trường
Kiểm tra SQL Server, SSAS Multidimensional, thư viện AMO và ADOMD, Python cùng pyarrow và lxml, Power BI Desktop hỗ trợ PBIP, các đường dẫn package và dữ liệu. Đặt đúng SqlServer, SsasServer, PackageRoot, ScriptsRoot, DataRoot và PythonExe. Tài khoản chạy cần quyền tương ứng; không lưu mật khẩu trong source hoặc tự tăng quyền để vượt lỗi cấu hình.

Thực hiện Preflight để kiểm tra kết nối và thư viện. Đối chiếu package thực sự được runner đọc với bản source cần triển khai; khi Visual Studio đang mở file, reload từ đĩa trước khi sửa để tránh lưu bản cũ đè bản mới. Backup hoặc cài đặt ban đầu là tác vụ riêng, không chạy installer cho mỗi đợt ETL.
## C.2 Chạy mới và theo dõi
Trong Master đặt khoảng tháng, giới hạn dòng, pResumeRunId trống, pStartStage Extract và retry phù hợp. Khởi chạy một điểm vào thống nhất, theo dõi RunId, stage, file và lỗi trong monitor cùng log. MaxRows 0 nghĩa đọc đầy đủ file được chọn, không có nghĩa xóa và tái tạo mọi lịch sử DWH.

Chờ đủ Extract, Transform, Dwh, Aggregates và Ssas; kiểm tra PipelineRun SUCCEEDED và đối soát trước khi khai thác dashboard. Không coi số dòng wrk hoặc card cũ của Power BI là bằng chứng run mới hoàn tất. Không chạy thêm package con trong lúc Master đang giữ khóa.
## C.3 Chạy lại sau lỗi
Đọc failure JSON, PipelineStep và stderr theo đúng RunId và InvocationId. Sửa nguyên nhân, xác nhận tiến trình cũ đã dừng và điều kiện khóa; dùng lại RunId cũ cùng cấu hình để resume từ stage được phép. Nếu stage trước chưa StageComplete SUCCEEDED, chạy từ điểm sớm hơn thay vì sửa log thủ công.

Nếu run bị bỏ dở còn RUNNING, dùng quy trình Recover-Run chủ động có kiểm tra applock; không tự coi thiếu heartbeat là tiến trình đã chết. Khi SSAS hoặc đối soát cuối lỗi, SQL có thể đã commit; cần giữ đầu vào ổn định và chạy lại stage cuối theo checkpoint. Một run không phải transaction phân tán xuyên file, SQL và cube.
## C.4 Mở báo cáo và thực hiện demo
Kiểm tra SSAS Processed và probe truy vấn thành công. Mở project PBIP cùng đầy đủ thư mục Report và SemanticModel; chọn năm tháng có dữ liệu và giữ bộ lọc tương đương khi chuyển project. Refresh Power BI chỉ truy vấn lại cube. Thực hiện lần lượt các câu hỏi YellowGreen, tip, HVFHV, FHV, tài chính, địa lý và base; nêu rõ phạm vi sample trước khi nhận xét.
## C.5 Bảo trì đối soát và khôi phục
Theo dõi log, file alert, checkpoint FAILED và thay đổi schema nguồn. Khi cần, chạy full reconciliation lúc ETL không hoạt động; nếu phát hiện sửa fact ngoài luồng, đánh ForceReload đúng file sau khi xác minh nguyên nhân. Sửa rule hoặc mapping phải có phiên bản và fixture tương ứng.

Backup database, source và metadata mô hình cần có phạm vi, retention và ca restore kiểm chứng riêng. Hồ sơ có backup không đủ để xác nhận phục hồi thảm họa đã hoàn thiện. Trước khi thay thế database hoặc khôi phục bản cũ phải đánh giá dữ liệu phát sinh sau backup; các thao tác đó không thuộc lần biên soạn báo cáo.

from pathlib import Path
from copy import deepcopy
import json,hashlib
from docx import Document
from docx.shared import Pt,RGBColor
from docx.oxml.ns import qn
R=Path(r'E:/NYCTaxi/NYCTaxi_SSAS');W=R/'report_work/chapter1';SOURCE=R/'BaoCao_NYCTaxi_5Chuong.docx'
src=Document(SOURCE);d=Document(SOURCE)
def text(el):return ''.join(el.xpath('.//w:t/text()'))
def sty(el):
 x=el.find(qn('w:pPr')+'/'+qn('w:pStyle'));return x.get(qn('w:val')) if x is not None else ''
keep=[];active=False
for el in src._element.body:
 if sty(el)=='Heading2' and text(el)=='1.4 Từ điển dữ liệu nguồn':active=True
 if sty(el)=='Heading2' and text(el).startswith('1.5 '):active=False
 if active:keep.append(deepcopy(el))
assert keep and sum(el.tag==qn('w:tbl') for el in keep)==5
for el in list(d._element.body):
 if el.tag!=qn('w:sectPr'):d._element.body.remove(el)
def p(t):
 x=d.add_paragraph(t,'Normal');x.paragraph_format.widow_control=True;return x
def h(t,l):
 x=d.add_paragraph(t,'Heading '+str(l));x.paragraph_format.keep_with_next=True;x.paragraph_format.page_break_before=False
 for r in x.runs:r.font.name='Times New Roman';r.font.size=Pt(14);r.font.color.rgb=RGBColor(0,0,0)
def prose(s):
 for t in s.strip().split('\n\n'):p(t.replace('\n',' '))
h('CHƯƠNG 1 TỔNG QUAN VỀ DỮ LIỆU NYC TAXI',1)
h('1.1 Giới thiệu đề tài',2)
h('1.1.1 Bối cảnh và lý do lựa chọn đề tài',3)
prose('''Vận tải hành khách bằng taxi và xe đặt trước là một bộ phận trong hoạt động đi lại của thành phố New York. Mỗi chuyến đi gắn với một nhu cầu di chuyển cụ thể, có thời điểm bắt đầu, địa điểm đón, địa điểm trả và những thông tin phục vụ đi kèm. Khi được tập hợp theo thời gian, dữ liệu chuyến đi cho phép tìm hiểu nhu cầu di chuyển, đặc điểm phục vụ giữa các khu vực và sự khác biệt giữa các loại hình vận tải.

Dữ liệu NYC Taxi được lựa chọn vì bao gồm nhiều loại hình dịch vụ cùng hoạt động trong một thành phố nhưng có cách nhận khách và phạm vi thông tin khác nhau. Taxi Yellow, taxi Green, xe FHV và xe HVFHV không phải bốn tên gọi tương đương. Việc hiểu đúng từng nhóm là điều kiện để đọc các bản ghi, giải thích các trường dữ liệu và đặt câu hỏi phân tích phù hợp.

Chương này giới thiệu bối cảnh của bộ dữ liệu, đặc điểm các loại hình taxi, nguồn cung cấp và ý nghĩa của các trường. Trọng tâm là hiểu đối tượng được ghi nhận và giới hạn của thông tin được công bố.''')
h('1.1.2 Mục tiêu nghiên cứu dữ liệu',3)
prose('''Mục tiêu đầu tiên là xác định một bản ghi mô tả sự kiện gì, thuộc loại dịch vụ nào và có những thông tin nào đi kèm. Các nhóm thông tin được quan tâm gồm thời gian, địa điểm, số hành khách, quãng đường, cách nhận chuyến, phương thức thanh toán và các khoản tiền được nguồn ghi nhận.

Mục tiêu tiếp theo là làm rõ những khía cạnh có thể so sánh giữa các nguồn. Số chuyến hoặc nơi đón khách có thể xuất hiện ở nhiều nhóm dịch vụ, trong khi tiền tài xế và thời điểm yêu cầu xe chỉ có ở những nguồn nhất định. Việc nhận diện sự khác biệt này giúp tránh đặt câu hỏi vượt quá khả năng của dữ liệu, chẳng hạn yêu cầu doanh thu của FHV khi bản ghi nguồn không cung cấp thông tin tài chính tương ứng.

Trên cơ sở đó, đề tài hướng đến việc tìm hiểu nhu cầu theo thời gian và địa bàn, đặc điểm chuyến đi, các khoản tiền ghi nhận và hoạt động điều phối của đơn vị cung cấp dịch vụ. Những nhận xét được giới hạn trong tập dữ liệu được sử dụng, không mặc nhiên đại diện cho toàn bộ hoạt động vận tải của New York.''')
h('1.1.3 Phạm vi dữ liệu',3)
prose('''Phạm vi nghiên cứu gồm bốn nhóm bản ghi chuyến đi: Yellow Taxi Trip Records, Green Taxi Trip Records, For-Hire Vehicle Trip Records và High Volume For-Hire Vehicle Trip Records. Danh mục Taxi Zone Lookup được dùng để giải thích mã vùng nơi đón và nơi trả khách.

Đối tượng quan sát chủ yếu là chuyến đi. Một dòng dữ liệu không đồng nghĩa với một hành khách duy nhất, một tài xế duy nhất hoặc toàn bộ hoạt động của một phương tiện trong ngày. Bộ dữ liệu được sử dụng cũng không phải hồ sơ kế toán đầy đủ của doanh nghiệp vận tải và không cung cấp đầy đủ chi phí để xác định lợi nhuận ròng.''')
h('1.2 Mô tả kỹ thuật các loại hình taxi',2)
p('Mục này mô tả từng loại dịch vụ theo cách nhận khách, phạm vi phục vụ và thông tin chuyến đi được ghi nhận. Những đặc điểm này giúp phân biệt các bộ dữ liệu trước khi đọc từ điển trường ở mục 1.4.')
h('1.2.1 Taxi Yellow',3)
prose('''Taxi Yellow là taxi màu vàng truyền thống của New York, hoạt động trong hệ thống taxi được cấp phép medallion. Đặc điểm nhận diện nghiệp vụ là khả năng nhận khách vẫy xe trên đường trong phạm vi thành phố theo quy định TLC. Khách có thể tiếp cận xe đang sẵn sàng phục vụ mà không nhất thiết phải đặt chuyến trước qua một đơn vị điều phối. Taxi Yellow cũng có thể nhận chuyến qua hình thức gọi xe điện tử được cấp phép [1], [3].

Với các chuyến ghi nhận bằng đồng hồ, dữ liệu thể hiện thời điểm bắt đầu và kết thúc chuyến, khu vực đón trả, quãng đường, số hành khách và thông tin thanh toán. Các khoản tiền được tách thành cước cơ bản, phụ thu, thuế, phí cầu đường, tiền tip và tổng tiền theo bản ghi. Vì vậy, khi đọc dữ liệu cần phân biệt cước chuyến đi với tổng số tiền được ghi nhận từ khách.

VendorID trong bản ghi Yellow là mã nhà cung cấp công nghệ ghi nhận dữ liệu, không phải mã hành khách, tài xế hay tên hãng taxi. Số hành khách là thông tin được nguồn ghi nhận cho chuyến; không dùng trường này thay cho số chuyến đi. Các trường tiền tip của taxi cũng không bao gồm đầy đủ tip tiền mặt, nên không thể dựa vào đó để kết luận hành khách trả tiền mặt không có tip [5].

Nhóm dữ liệu Yellow phù hợp để tìm hiểu phân bố chuyến theo thời gian, địa bàn, quãng đường, mức cước và hình thức thanh toán. Mỗi kết quả cần được đọc cùng khoảng thời gian và phạm vi bản ghi được lựa chọn.''')
h('1.2.2 Taxi Green',3)
prose('''Taxi Green là taxi màu xanh, còn được gọi là Boro Taxi hoặc Street Hail Livery, viết tắt SHL. Loại hình này được giới thiệu nhằm tăng khả năng tiếp cận dịch vụ taxi tại các khu vực ngoài vùng tập trung đón khách của taxi vàng. Về hình thức phục vụ, Green có thể nhận khách vẫy xe trong vùng được phép và có các phương thức nhận chuyến đặt trước hoặc gọi xe điện tử theo quy định tương ứng [1], [2], [3].

Phạm vi nhận khách vẫy xe là điểm khác biệt quan trọng so với Yellow. Vùng đón vẫy xe của Green tập trung ở các quận ngoài Manhattan và phía bắc Manhattan; không được hiểu rằng Green có cùng quyền đón khách vẫy xe với Yellow ở mọi địa điểm. Tài liệu TLC nêu giới hạn ở Manhattan phía nam East 96th Street và West 110th Street, cùng các hạn chế liên quan sân bay. Cần phân biệt quy định về đón khách với việc chuyến đi có thể kết thúc ở một khu vực khác [1], [2].

Bản ghi Green có nhiều nhóm thông tin tương tự Yellow: thời gian, điểm đón trả, số hành khách, quãng đường, thanh toán và các khoản tiền. Trường trip_type bổ sung thông tin phân biệt chuyến nhận khách vẫy xe với chuyến được điều phối. Những tên trường lpep là cách đặt tên của bộ dữ liệu Green, còn tpep là cách đặt tên tương ứng trong bộ Yellow.

Sự giống nhau về nhóm thông tin không có nghĩa Yellow và Green là một dịch vụ duy nhất. Khi nhận xét nhu cầu hoặc tài chính, cần biết bản ghi thuộc nguồn nào, cách nhận chuyến là gì và phạm vi phục vụ của loại xe đó. Địa điểm xuất hiện trong dữ liệu không tự nó chứng minh một cách nhận khách đã được phép tại địa điểm ấy.''')
h('1.2.3 Dịch vụ For Hire Vehicle FHV',3)
prose('''For-Hire Vehicle, viết tắt FHV, là nhóm xe phục vụ chuyến được đặt trước thông qua đơn vị cung cấp hoặc điều phối dịch vụ. Các nhóm thường được nhắc đến gồm livery, black car và limousine theo phân loại giấy phép TLC. Khác với nhận khách vẫy xe trực tiếp, chuyến FHV gắn với việc có yêu cầu trước rồi đơn vị phục vụ bố trí xe [1], [4].

Base là đơn vị có vai trò tiếp nhận hoặc điều phối chuyến theo giấy phép. Base không phải là địa điểm khách lên xe và cũng không phải là tài xế. Trong bản ghi FHV, dispatching_base_num cho biết base điều phối; Affiliated_base_number cho biết base mà xe liên kết theo thông tin nguồn. Hai vai trò này cần được đọc đúng tên thay vì coi mọi mã base là một loại thông tin giống nhau.

Dữ liệu FHV trong phạm vi đề tài chủ yếu cung cấp thời gian đón trả, mã vùng, các mã base và SR_Flag. So với Yellow và Green, nguồn này không có đầy đủ các cột cước và phương thức thanh toán. Vì vậy, việc không có thông tin tiền trong bản ghi không có nghĩa chuyến FHV miễn phí; đó là giới hạn của tập thông tin được công bố.

FHV phù hợp để tìm hiểu số chuyến, diễn biến thời gian, phân bố vùng và hoạt động của base. Riêng SR_Flag phải đọc theo từ điển và thời kỳ của nguồn; không coi cờ này tự động có cùng ý nghĩa với mọi cờ chuyến đi chung ở bộ dữ liệu khác.''')
h('1.2.4 Dịch vụ High Volume For Hire Vehicle HVFHV',3)
prose('''High Volume For-Hire Vehicle, thường được ký hiệu HVFHV trong tên bộ dữ liệu, mô tả các chuyến thuộc nhóm dịch vụ đặt xe có quy mô điều phối lớn. Trong khi HVFHV thường dùng để nói đến bản ghi chuyến, HVFHS là tên loại giấy phép của dịch vụ hoặc doanh nghiệp. Đây là nhóm thuộc phạm vi xe đặt trước, không phải một màu taxi tương tự Yellow hoặc Green [4], [6].

Các bản ghi có thể phản ánh chuyến được đặt qua các nền tảng như Uber hoặc Lyft, tùy giấy phép và thời kỳ dữ liệu. Không được coi tất cả bản ghi HVFHV đều thuộc cùng một thương hiệu. Trường hvfhs_license_num nhận diện giấy phép nhà cung cấp; dispatching_base_num và originating_base_num lần lượt mô tả base điều phối và base nhận yêu cầu ban đầu.

Nguồn HVFHV chứa nhiều mốc phục vụ hơn các bộ taxi truyền thống, gồm thời điểm khách yêu cầu, thời điểm xe đến nơi đón khi được cung cấp, thời điểm đón và thời điểm trả. Nguồn còn có quãng đường, thời lượng, cước cơ bản, thuế phí, tip và tiền tài xế. Tuy nhiên, không phải mọi trường đều có độ bao phủ như nhau; on_scene_datetime trong từ điển TLC gắn với xe tiếp cận, nên thiếu mốc này không đủ để kết luận xe không đến [6].

Các cờ dịch vụ phản ánh những sự kiện khác nhau. Khách đồng ý hoặc yêu cầu đi chung chưa chắc đã được ghép với một khách đặt riêng khác. Tương tự, khách yêu cầu xe hỗ trợ xe lăn khác với chuyến thực tế được thực hiện bằng loại xe đó. Phân biệt yêu cầu và kết quả phục vụ là cần thiết khi diễn giải những thông tin này.

Các khoản tiền cũng có phạm vi riêng: cước cơ bản chưa đồng nghĩa tổng tiền khách; tiền trả tài xế chưa đồng nghĩa lợi nhuận ròng sau mọi chi phí của người lái. Dữ liệu cho phép mô tả các khoản được ghi nhận, nhưng không tự cung cấp một báo cáo kết quả kinh doanh đầy đủ.''')
h('1.2.5 Phân biệt các loại hình dịch vụ',3)
prose('''Yellow và Green là hai nhóm taxi có nhận diện màu sắc và đặc điểm nhận khách vẫy xe, trong đó phạm vi được phép nhận khách của Green có giới hạn khác Yellow. FHV và HVFHV được nhận diện theo hình thức đặt trước, tổ chức điều phối và nhóm giấy phép; chúng không phải hai màu xe bổ sung vào danh sách taxi.

Cần phân biệt phân loại ngành vận tải với cách chia file công bố. Green có đặc điểm giấy phép SHL trong hệ sinh thái quản lý FHV, nhưng được TLC công bố thành bộ Green riêng. Tương tự, HVFHV thuộc nhóm xe đặt trước nhưng có bộ dữ liệu riêng và chi tiết hơn từ năm 2019. Vì vậy, trong phạm vi dữ liệu đề tài, tên Yellow, Green, FHV và HVFHV được dùng để chỉ bốn nhóm bản ghi được công bố riêng, không mặc nhiên là bốn khái niệm pháp lý hoàn toàn tách rời [2], [4].''')
h('1.2.6 Quy trình phục vụ một chuyến đi',3)
prose('''Với khách vẫy xe, quá trình được quan sát thường bắt đầu khi xe nhận khách, tiếp tục bằng hành trình di chuyển và kết thúc khi khách xuống xe, thanh toán. Các mốc thời gian của Yellow và Green chủ yếu phản ánh thời điểm bắt đầu và kết thúc theo đồng hồ. Bản ghi có thể kèm số hành khách, quãng đường và các khoản thu của chuyến.

Với chuyến đặt trước, quá trình còn có bước tạo yêu cầu và điều phối xe trước khi đón. Khách gửi yêu cầu, đơn vị dịch vụ bố trí xe, xe đến điểm đón, khách lên xe và chuyến kết thúc ở điểm trả. Tùy nguồn, một số mốc hoặc đơn vị tham gia được thể hiện chi tiết hơn các nguồn khác. Việc một bộ dữ liệu không có cột thời điểm yêu cầu không chứng minh chuyến đi không được đặt trước.

Một chuyến có điểm đón và điểm trả, nhưng hai sự kiện này có thể khác vùng hoặc khác ngày. Bởi vậy số lượt đón trong một vùng không nhất thiết bằng số lượt trả trong vùng đó. Khi đặt câu hỏi về nhu cầu đi lại cần xác định đang quan tâm đến nơi bắt đầu, nơi kết thúc hay toàn bộ hành trình.''')
h('1.3 Mô tả nguồn dữ liệu',2)
h('1.3.1 Đơn vị cung cấp dữ liệu',3)
prose('''Nguồn dữ liệu chính là trang TLC Trip Record Data do NYC Taxi and Limousine Commission công bố. TLC cung cấp các nhóm bản ghi chuyến, từ điển dữ liệu và danh mục vùng để người sử dụng tìm hiểu hoạt động vận tải hành khách tại New York [4]. Địa chỉ nguồn: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page.

Dữ liệu Yellow và Green được hình thành từ các hệ thống công nghệ ghi nhận hoạt động taxi và được các đơn vị liên quan cung cấp cho TLC. Dữ liệu FHV xuất phát từ hồ sơ chuyến mà các base gửi, còn nhóm dịch vụ quy mô lớn có bộ bản ghi riêng. Vì vậy, TLC là đầu mối công bố và hướng dẫn ý nghĩa dữ liệu; không nên hiểu rằng mọi giá trị trong từng dòng đều được cơ quan này trực tiếp tạo và xác nhận đầy đủ.''')
h('1.3.2 Các bộ dữ liệu được sử dụng',3)
prose('''Yellow Taxi Trip Records chứa thông tin chuyến taxi vàng. Green Taxi Trip Records chứa thông tin chuyến taxi xanh hoặc SHL. For-Hire Vehicle Trip Records chứa thông tin chuyến xe đặt trước theo cấu trúc nguồn FHV. High Volume For-Hire Vehicle Trip Records chứa thông tin chi tiết của nhóm dịch vụ đặt xe quy mô lớn. Taxi Zone Lookup cung cấp danh mục giải thích mã vùng xuất hiện trong các bản ghi.

Các nhóm chuyến có thể được dùng để quan sát một số khía cạnh chung như thời điểm và địa điểm, nhưng mức độ chi tiết không giống nhau. Những thông tin chỉ có ở một nguồn cần được giới thiệu đúng phạm vi. Ví dụ, tiền tài xế trong HVFHV không đồng nghĩa các nguồn khác cũng có một cột với ý nghĩa tương tự.''')
h('1.3.3 Cách công bố và tổ chức file',3)
prose('''Trang công bố sắp xếp các liên kết theo năm, tháng và loại dịch vụ. Dữ liệu chuyến đi được cung cấp dưới dạng file Parquet; danh mục Taxi Zone Lookup có bản CSV. Tên file chuyến thường thể hiện nhóm dịch vụ và kỳ dữ liệu, chẳng hạn yellow_tripdata_2025-01.parquet hoặc fhvhv_tripdata_2025-01.parquet. Cách đặt tên này giúp nhận biết nội dung khái quát của file trước khi đọc các trường.

Một file chuyến chứa nhiều bản ghi chi tiết; mỗi dòng được hiểu trong bối cảnh của nguồn tương ứng. Tháng trên tên file là kỳ công bố hoặc kỳ tổ chức dữ liệu, không nên dùng thay cho việc đọc thời điểm thực tế trong từng bản ghi. Những thời điểm bất thường hoặc ngoài kỳ cần được xem xét như vấn đề chất lượng dữ liệu.

Các bộ dữ liệu không bắt đầu cùng thời điểm và không phải kỳ nào cũng có cấu trúc trường hoàn toàn giống nhau. Chẳng hạn, Green được giới thiệu từ năm 2013 và HVFHV được công bố tách riêng từ năm 2019. TLC có thể cập nhật file hoặc bổ sung trường ở các thời kỳ mới; vì vậy cần đọc từ điển đi kèm kỳ dữ liệu đang sử dụng [4], [7].''')
h('1.3.4 Danh mục vùng Taxi Zone Lookup',3)
prose('''Taxi Zone Lookup giải thích các mã LocationID trong bản ghi chuyến. Những thông tin chính gồm mã vùng, Borough, tên Zone và service_zone. PULocationID chỉ vùng đón khách, còn DOLocationID chỉ vùng trả khách. Cùng một danh mục được dùng để đọc ý nghĩa của hai loại mã vị trí này.

Taxi Zone là đơn vị vùng dùng trong bộ dữ liệu, không phải địa chỉ nhà hoặc tọa độ chính xác của hành khách. Borough thể hiện nhóm địa lý ở cấp quận, còn Zone mô tả vùng chi tiết hơn. Do vậy, dữ liệu vị trí phù hợp để xem phân bố theo vùng nhưng không cho phép tự suy ra toàn bộ lộ trình xe đã đi hoặc danh tính người sử dụng.

Một mã vị trí thiếu hoặc không tìm thấy trong danh mục làm giảm khả năng diễn giải về địa lý của chuyến. Điều này không tự chứng minh chuyến đi không xảy ra. Khi trình bày kết quả theo vùng, cần phân biệt nhóm có vị trí xác định với phần chưa xác định.''')
h('1.3.5 Đặc điểm của thông tin được công bố',3)
prose('''Các bản ghi phản ánh những thông tin mà nguồn cung cấp ở thời điểm công bố. Những tên cột gần giống nhau giữa các nguồn cần được đọc theo từ điển riêng. Đơn vị tiền chủ yếu là USD, quãng đường thường là mile, còn thời lượng nguồn HVFHV được mô tả bằng giây. Ngày giờ cần đọc theo ngữ cảnh bản ghi, không tự diễn giải thành giờ Việt Nam.

TLC nêu giới hạn về tính chính xác và đầy đủ của các dữ liệu do đơn vị cung cấp gửi. Ngoài giá trị thiếu, có thể có thông tin bất thường về thời gian, vị trí, quãng đường hoặc khoản tiền. Việc mô tả nguồn vì vậy cần đi cùng những giới hạn này thay vì mặc nhiên xem tất cả bản ghi là quan sát hoàn chỉnh [4].''')
# Retain section 1.4 paragraphs and every table cell without rewriting.
for el in keep:d._element.body.insert(-1,el)
h('1.5 Đặc điểm chất lượng và giới hạn diễn giải dữ liệu',2)
prose('''Dữ liệu có thể thiếu số hành khách, vị trí hoặc một mốc thời gian. Giá trị chưa được cung cấp khác với một giá trị bằng 0 có ý nghĩa nghiệp vụ. Chẳng hạn, không có thông tin tiền tài xế không đồng nghĩa tài xế không nhận tiền; không ghi nhận tip tiền mặt không đồng nghĩa hành khách không tip. Mỗi trường cần được đọc cùng nguồn và kỳ dữ liệu.

Những giá trị như thời điểm trả trước thời điểm đón, quãng đường âm hoặc thời lượng rất lớn cần được xem xét trước khi dùng để nhận xét hoạt động vận tải. Tuy nhiên, một giá trị khác thường không tự xác định được nguyên nhân là lỗi nhập liệu, điều chỉnh nghiệp vụ hay đặc điểm chuyến. Chương này chỉ nêu đặc điểm và giới hạn của thông tin; các quy tắc xử lý được trình bày ở phần triển khai tương ứng.

Tập dữ liệu dùng trong đồ án là một phần dữ liệu được lựa chọn từ nguồn công bố. Nếu chỉ sử dụng một phần đầu của file tháng, kết quả có thể chủ yếu phản ánh một số ngày hoặc khung giờ nhất định. Không dùng số liệu của tập này để khẳng định thị phần toàn thành phố hoặc nhu cầu của cả tháng khi độ bao phủ chưa được xác nhận.

Các khoản thu ghi nhận chưa đủ để tính lợi nhuận ròng của doanh nghiệp hoặc tài xế vì còn thiếu nhiều chi phí. Sự thay đổi đồng thời giữa phí và số chuyến cũng chưa chứng minh phí là nguyên nhân gây ra biến động nhu cầu. Những giới hạn này cần đi cùng các kết luận sử dụng dữ liệu.''')
h('1.6 Các câu hỏi phân tích đặt ra từ dữ liệu',2)
prose('''Về nhu cầu đi lại, đề tài quan tâm số chuyến biến động như thế nào theo tháng, ngày trong tuần và giờ; những vùng nào có nhiều lượt đón hoặc lượt trả; phân bố chuyến của Yellow, Green, FHV và HVFHV khác nhau ra sao trong cùng phạm vi quan sát.

Về đặc điểm phục vụ, các câu hỏi gồm quãng đường và thời lượng chuyến khác nhau theo thời gian, vùng hoặc dịch vụ như thế nào; thời gian từ yêu cầu đến đón khách ở nhóm HVFHV có khác nhau theo nhà cung cấp và địa bàn hay không. Những câu hỏi cần một trường riêng chỉ được đặt cho nguồn thực sự có thông tin đó.

Về tài chính, đề tài tìm hiểu cước cơ bản, tổng tiền khách, tip và các khoản thuế phí được ghi nhận thay đổi ra sao theo kỳ và loại dịch vụ. Đối với taxi, có thể xem khác biệt theo phương thức thanh toán nhưng phải nêu giới hạn tip tiền mặt. Đối với HVFHV, có thể xem các khoản tiền tài xế được ghi nhận mà không gọi đó là lợi nhuận ròng.

Về điều phối, các câu hỏi tập trung số chuyến theo base, sự khác biệt giữa đơn vị nhận yêu cầu và đơn vị điều phối khi có thông tin, cùng đặc điểm yêu cầu đi chung hoặc xe tiếp cận. Các câu hỏi này hình thành từ nội dung dữ liệu và không quyết định trước cách thiết kế hay công cụ thực hiện ở những chương sau.''')
h('Tài liệu tham khảo của Chương 1',2)
for t in [
'[1] TLC Your Ride. https://www.nyc.gov/site/tlc/passengers/your-ride.page.',
'[2] TLC Green Cab và Street Hail Livery Permit. https://www.nyc.gov/site/tlc/businesses/green-cab.page; https://www.nyc.gov/site/tlc/businesses/street-hail-livery-permit.page.',
'[3] TLC E-Hail Providers. https://www.nyc.gov/site/tlc/businesses/e-hail-providers.page.',
'[4] TLC Trip Record Data. https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page.',
'[5] TLC Yellow Taxi Data Dictionary. https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf.',
'[6] TLC High Volume FHV Data Dictionary. https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_hvfhs.pdf.',
'[7] TLC Trip Record User Guide. https://www.nyc.gov/assets/tlc/downloads/pdf/trip_record_user_guide.pdf.']:p(t)
# The only approved technical dictionary is section 1.4, left intact.
out=R/'Chuong1_TongQuanDuLieu_NYCTaxi.docx';d.save(out)
def tables_content(doc):return [[[c.text for c in row.cells] for row in t.rows] for t in doc.tables]
original=Document(SOURCE);original14=[];on=False
for el in original._element.body:
 if sty(el)=='Heading2' and text(el)=='1.4 Từ điển dữ liệu nguồn':on=True
 if sty(el)=='Heading2' and text(el).startswith('1.5 '):on=False
 if on and el.tag==qn('w:tbl'):
  from docx.table import Table
  original14.append([[c.text for c in row.cells] for row in Table(el,original._body).rows])
assert tables_content(d)==original14
(W/'artifact.md').write_text('Task: revise only Chapter 1 as a standalone review document. Copy styles and A4 geometry from the current report. Section 1.2 describes Yellow Green FHV HVFHV; 1.3 describes source and file organization. Preserve section 1.4 body and five tables unchanged. Remove implementation and design discussion from all other sections. No new claims of execution, schemas or processing. Black headings and unshaded tables retained. Source report left unchanged. Native Word render and page QA required.',encoding='utf-8')
(W/'audit.json').write_text(json.dumps({'section_1_4_tables_unchanged':True,'table_count':len(d.tables),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest()},indent=2),encoding='utf-8')
print(out)

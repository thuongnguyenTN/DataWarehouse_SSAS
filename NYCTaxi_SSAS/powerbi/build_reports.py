"""Generate native PBIP/PBIR thin reports, one SSAS live connection per cube.
Field names come from the server's CSDL ReferenceName, not guessed SQL names.
"""
from pathlib import Path
import json, hashlib
from lxml import etree as E

ROOT=Path(__file__).parent
OUT=ROOT/'reports'
BASE='https://developer.microsoft.com/json-schemas/fabric/item/'
SERVER=r'THUONGNGUYEN\MSSQLSV'
SERVICE_COLORS={'YELLOW':'#C99400','GREEN':'#238B45','FHV':'#7560B5','FHVHV':'#087E8B'}
SERIES_COLORS=['#2765A8','#E07B24','#238B45','#7560B5','#C99400','#087E8B']
BI='{http://schemas.microsoft.com/sqlbi/2010/10/edm/extensions}'
ED='{http://schemas.microsoft.com/ado/2008/09/edm}'

def dump(p,obj):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding='utf-8')

def metadata(cube):
    r=E.parse(str(ROOT/'metadata'/f'{cube}.csdl.xml'))
    tables={}
    for s in r.findall('.//'+ED+'EntitySet'):
        a=s.find(BI+'EntitySet')
        tables[s.get('Name')]=a.get('ReferenceName',s.get('Name')) if a is not None else s.get('Name')
    fields={};measures={}
    for t in r.findall('./'+ED+'EntityType'):
        name=tables[t.get('Name')]
        for p in t.findall(ED+'Property'):
            m=p.find(BI+'Measure');a=p.find(BI+'Property')
            if m is not None:
                ref=m.get('ReferenceName',p.get('Name'));measures[ref]=(name,ref)
            elif a is not None and a.get('Hidden')!='true':
                ref=a.get('ReferenceName',p.get('Name'));fields[(name,ref)]=(name,ref)
    return fields,measures

def lit(s):return {'expr':{'Literal':{'Value':"'"+str(s).replace("'","''")+"'"}}}
def boolean(v):return {'expr':{'Literal':{'Value':'true' if v else 'false'}}}
def num(v):return {'expr':{'Literal':{'Value':str(v)+'D'}}}
def color(c):return {'solid':{'color':lit(c)}}
def expr(t,p,measure=False):
    return {('Measure' if measure else 'Column'):{'Expression':{'SourceRef':{'Entity':t}},'Property':p}}
def proj(t,p,measure=False,label=None):
    o={'field':expr(t,p,measure),'queryRef':t+'.'+p,'nativeQueryRef':p}
    if label:o['displayName']=label
    return o

INDEX=[];CHECKS=[]
class Report:
    def __init__(self,cube,title,accent):
        self.cube=cube;self.title=title;self.accent=accent
        self.fields,self.measures=metadata(cube)
        self.home=OUT/cube;self.report=self.home/(cube+'.Report');self.pages=[];self.i=0
        model=self.home/(cube+'.SemanticModel')
        dump(model/'definition.pbism',{'version':'4.0','settings':{}})
        dump(model/'modelReference.json',{'$schema':BASE+'semanticModel/modelReference/2.0.0/schema.json',
            'connectionString':f'Data Source={SERVER};Initial Catalog=NYCTaxi_SSAS;Cube="{title}";Integrated Security=SSPI;',
            'isMultiDimentional':True,'connectionType':'analysisServicesDatabaseLive'})
        dump(self.report/'definition.pbir',{'$schema':BASE+'report/definitionProperties/2.0.0/schema.json',
            'version':'4.0','datasetReference':{'byPath':{'path':'../'+cube+'.SemanticModel'}}})
        dump(self.home/(cube+'.pbip'),{'version':'1.0','artifacts':[{'report':{'path':cube+'.Report'}}],'settings':{'enableAutoRecovery':True}})
        dump(self.report/'definition/version.json',{'$schema':BASE+'report/definition/versionMetadata/1.0.0/schema.json','version':'2.0.0'})
        dump(self.report/'definition/report.json',{'$schema':BASE+'report/definition/report/3.1.0/schema.json','themeCollection':{},
            'settings':{'useStylableVisualContainerHeader':True},
            'annotations':[{'name':'Source','value':'SSAS Multidimensional Live; no imported data'}]})
        INDEX.append({'cube':cube,'title':title,'path':str((self.home/(cube+'.pbip')).relative_to(ROOT)),'pages':self.pages})
    def col(self,t,p):
        assert (t,p) in self.fields,(self.cube,t,p,'Column missing in CSDL')
        return (t,p,False)
    def mea(self,p):
        assert p in self.measures,(self.cube,p,'Measure missing in CSDL')
        t,p=self.measures[p];return(t,p,True)
    def visual(self,typ,title,x,y,w,h,roles=None,sort=None):
        self.i+=1;name=hashlib.sha1((self.cube+self.page+str(self.i)).encode()).hexdigest()[:20]
        v={'visualType':typ,'drillFilterOtherVisuals':True,
           'visualContainerObjects':{'title':[{'properties':{'show':boolean(True),'text':lit(title),'fontColor':color('#18334B'),'fontSize':num(12)}}],
            'background':[{'properties':{'show':boolean(True),'color':color('#FFFFFF'),'transparency':num(0)}}],
            'border':[{'properties':{'show':boolean(True),'color':color('#DFE7ED'),'radius':num(8)}}]}}
        if roles:
            qs={}
            for role,fields in roles.items():
                qs[role]={'projections':[proj(*f) for f in fields]}
                for f in fields:CHECKS.append({'cube':self.cube,'table':f[0],'property':f[1],'measure':f[2]})
            v['query']={'queryState':qs}
            if sort:
                v['query']['sortDefinition']={'sort':[{'field':expr(*sort[0]),'direction':sort[1]}],'isDefaultSort':False}
        if typ=='card':
            v['objects']={'labels':[{'properties':{'color':color(self.accent),'fontSize':num(29)}}],
                          'categoryLabels':[{'properties':{'show':boolean(False)}}]}
        elif typ=='slicer':
            v['objects']={'data':[{'properties':{'mode':lit('Dropdown')}}],
                          'selection':[{'properties':{'singleSelect':boolean(False),'selectAllCheckboxEnabled':boolean(True),'multiSelect':boolean(True)}}]}
        elif typ in ('lineChart','clusteredColumnChart','clusteredBarChart'):
            points=[]
            series=(roles or {}).get('Series',[])
            categories=(roles or {}).get('Category',[])
            service=next((f for f in series+categories if f[:2]==('Dim Service Type','Service Code')),None)
            if service:
                for code,hexcolor in SERVICE_COLORS.items():
                    points.append({'selector':{'data':[{'scopeId':{'Comparison':{'ComparisonKind':0,'Left':expr(*service),'Right':{'Literal':{'Value':"'"+code+"'"}}}}}]},'properties':{'fill':color(hexcolor)}})
            elif len((roles or {}).get('Y',[]))>1:
                for index,f in enumerate(roles['Y']):
                    points.append({'selector':{'metadata':f[0]+'.'+f[1]},'properties':{'fill':color(SERIES_COLORS[index%len(SERIES_COLORS)])}})
            else:
                points.append({'properties':{'defaultColor':color(self.accent)}})
            v['objects']={'dataPoint':points}
        o={'$schema':BASE+'report/definition/visualContainer/2.4.0/schema.json','name':name,
           'position':{'x':x,'y':y,'width':w,'height':h,'z':self.i,'tabOrder':self.i},'visual':v}
        dump(self.report/'definition/pages'/self.page/'visuals'/name/'visual.json',o)
        return o
    def text(self,text,x,y,w,h,size=11,bold=False,fg='#516679'):
        o=self.visual('textbox','',x,y,w,h)
        o['visual']['visualContainerObjects']['title'][0]['properties']['show']=boolean(False)
        o['visual']['objects']={'general':[{'properties':{'paragraphs':[{'textRuns':[{'value':text,'textStyle':{
            'fontFamily':'Segoe UI','fontSize':str(size)+'pt','fontWeight':'bold' if bold else 'normal','color':fg}}]}]}}]}
        dump(self.report/'definition/pages'/self.page/'visuals'/o['name']/'visual.json',o)
    def start(self,name,label,subtitle,notes,date='Pickup Date',extra=None):
        self.page=name;self.pages.append({'name':name,'label':label})
        dump(self.report/'definition/pages'/name/'page.json',{'$schema':BASE+'report/definition/page/2.0.0/schema.json',
            'name':name,'displayName':label,'displayOption':'FitToPage','width':1440,'height':960,
            'objects':{'background':[{'properties':{'color':color('#F2F6F9'),'transparency':num(0)}}]}})
        self.text('NYC TAXI  /  '+label.upper(),24,18,1392,44,23,True,'#16364C')
        self.text(subtitle+'  •  SSAS Live Connection',24,66,1392,32,11)
        self.visual('slicer','Năm',24,110,220,82,{'Values':[self.col(date,'Year Number')]})
        # Month Name is keyed by month alone; Month Number is keyed by year/month.
        self.visual('slicer','Tháng',256,110,220,82,{'Values':[self.col(date,'Month Name')]})
        self.visual('slicer','Dịch vụ',488,110,250,82,{'Values':[self.col('Dim Service Type','Service Code')]})
        if extra:self.visual('slicer',extra[0],750,110,350,82,{'Values':[self.col(*extra[1])]})
        self.text(notes,24,884,1392,58,10,False,'#6F591D')
    def cards(self,items):
        for i,(label,m) in enumerate(items):self.visual('card',label,24+i*350,210,342,110,{'Values':[self.mea(m)]})
    def chart(self,typ,title,col,ms,x,y,w=688,h=256,legend=None,descending=False):
        c=self.col(*col);roles={'Category':[c],'Y':[self.mea(m) for m in ms]}
        if legend:roles['Series']=[self.col(*legend)]
        sort=(self.mea(ms[0]),'Descending') if descending else (c,'Ascending')
        self.visual(typ,title,x,y,w,h,roles,sort)
    def finish(self):
        dump(self.report/'definition/pages/pages.json',{'$schema':BASE+'report/definition/pagesMetadata/1.0.0/schema.json',
            'pageOrder':[p['name'] for p in self.pages],'activePageName':self.pages[0]['name']})

def main():
    note='Phân tích trên dữ liệu đã nạp. Chọn cùng năm/tháng khi đối chiếu báo cáo; dữ liệu giới hạn dòng không đại diện toàn thị trường.'
    r=Report('YellowGreen_Trips','YellowGreen Trips','#C78B12')
    r.start('taxi_overview','Taxi truyền thống','Nhu cầu • giờ cao điểm • tiền khách trả',note,extra=('Quận đón',('Pickup Location','Borough')))
    r.cards([('Số chuyến','Trip Count - Fact Yellow Green Trips'),('Tiền khách trả · USD','Total Amount'),('Cước TB/chuyến · USD','YellowGreen Average Fare Per Trip'),('Tip / cước hợp lệ','YellowGreen Tip Percentage')])
    r.chart('lineChart','Xu hướng số chuyến theo ngày',('Pickup Date','Full Date'),['Trip Count - Fact Yellow Green Trips'],24,338)
    r.chart('clusteredColumnChart','Giờ đón khách cao điểm',('Pickup Time','Hour Number'),['Trip Count - Fact Yellow Green Trips'],728,338)
    r.chart('clusteredBarChart','Số chuyến theo quận đón',('Pickup Location','Borough'),['Trip Count - Fact Yellow Green Trips'],24,610,descending=True)
    r.chart('clusteredColumnChart','Tiền khách trả theo dịch vụ',('Dim Service Type','Service Code'),['Total Amount'],728,610)
    r.start('taxi_tips','Hành vi & tiền tip','Thanh toán • cuối tuần • khu vực',note+' Tip tiền mặt có thể không được ghi nhận đầy đủ; không suy diễn quan hệ nhân quả.',extra=('Thanh toán',('Dim Payment Type','Payment Type Key')))
    r.cards([('Tiền tip ghi nhận · USD','Tip Amount - Fact Yellow Green Trips'),('Tip / cước hợp lệ','YellowGreen Tip Percentage'),('Tip TB/chuyến hợp lệ · USD','YellowGreen Average Tip Per Trip'),('Thời lượng TB · phút','YellowGreen Average Trip Duration Minutes')])
    r.chart('clusteredBarChart','Tỷ lệ tip theo khu vực đón · xem thêm số chuyến',('Pickup Location','Zone Name'),['YellowGreen Tip Percentage'],24,338,descending=True)
    r.chart('clusteredColumnChart','Tỷ lệ tip theo hình thức thanh toán',('Dim Payment Type','Payment Type Key'),['YellowGreen Tip Percentage'],728,338)
    r.chart('clusteredColumnChart','Tỷ lệ tip: ngày thường / cuối tuần',('Pickup Date','Is Weekend'),['YellowGreen Tip Percentage'],24,610)
    r.chart('lineChart','Tỷ lệ tip theo giờ đón',('Pickup Time','Hour Number'),['YellowGreen Tip Percentage'],728,610)
    r.finish()

    r=Report('HVFHV_Trips','HVFHV Trips','#087E8B')
    r.start('hvfhv_overview','Xe công nghệ','Nhu cầu • thời gian chờ • tiền tài xế',note,extra=('Nhà cung cấp',('Dim HVFHS Provider','License Number')))
    r.cards([('Số chuyến','Trip Count - Fact HVFHV Trips'),('Tiền tài xế · USD','Driver Pay Amount'),('Chờ TB · phút','HVFHV Average Waiting Minutes'),('Cước TB/chuyến · USD','HVFHV Average Fare Per Trip')])
    r.chart('lineChart','Xu hướng số chuyến theo ngày',('Pickup Date','Full Date'),['Trip Count - Fact HVFHV Trips'],24,338)
    r.chart('clusteredColumnChart','Số chuyến theo giờ',('Pickup Time','Hour Number'),['Trip Count - Fact HVFHV Trips'],728,338)
    r.chart('clusteredBarChart','Thời gian chờ theo quận đón · phút',('Pickup Location','Borough'),['HVFHV Average Waiting Minutes'],24,610,descending=True)
    r.chart('clusteredBarChart','Số chuyến theo nhà cung cấp',('Dim HVFHS Provider','License Number'),['Trip Count - Fact HVFHV Trips'],728,610,descending=True)
    r.start('hvfhv_fees','Phí & thu nhập','Theo dõi biến động phí, tiền khách trả và tiền tài xế',note+' Biểu đồ mô tả đồng biến, chưa chứng minh tác động chính sách. Tiền tài xế không phải lợi nhuận.',extra=('Quận đón',('Pickup Location','Borough')))
    r.cards([('Phí ùn tắc · USD','Congestion Surcharge'),('Phí CBD · USD','CBD Congestion Fee'),('Tiền khách trả · USD','Gross Passenger Amount'),('Tiền tài xế · USD','Driver Pay Amount')])
    r.chart('lineChart','Phí ùn tắc và CBD theo ngày · USD',('Pickup Date','Full Date'),['Congestion Surcharge','CBD Congestion Fee'],24,338)
    r.chart('lineChart','Tiền khách trả và tài xế theo ngày · USD',('Pickup Date','Full Date'),['Gross Passenger Amount','Driver Pay Amount'],728,338)
    r.chart('clusteredBarChart','Phí ùn tắc theo quận đón · USD',('Pickup Location','Borough'),['Congestion Surcharge'],24,610,descending=True)
    r.chart('clusteredColumnChart','Số chuyến theo khung giờ',('Pickup Time','Time Band'),['Trip Count - Fact HVFHV Trips'],728,610)
    r.finish()

    r=Report('FHV_Trips','FHV Trips','#6260B4')
    r.start('fhv_overview','FHV truyền thống','Xu hướng chuyến đi • thời lượng • base điều phối',note+' Vùng Unknown được giữ trong biểu đồ; thiếu vùng ảnh hưởng kết luận địa lý.',extra=('Quận đón',('Pickup Location','Borough')))
    r.cards([('Số chuyến','Trip Count'),('Thời lượng TB · phút','FHV Average Trip Duration Minutes'),('Tổng thời lượng · giây','Trip Duration Seconds'),('Chuyến có thời lượng','Fact FHV Trips TripDurationSecondsValidTrips')])
    r.chart('lineChart','Xu hướng số chuyến theo ngày',('Pickup Date','Full Date'),['Trip Count'],24,338)
    r.chart('clusteredColumnChart','Số chuyến theo giờ đón',('Pickup Time','Hour Number'),['Trip Count'],728,338)
    r.chart('clusteredBarChart','Số chuyến theo quận đón, gồm Unknown',('Pickup Location','Borough'),['Trip Count'],24,610,descending=True)
    r.chart('clusteredBarChart','Số chuyến theo base điều phối',('Dispatch Base','Base Key'),['Trip Count'],728,610,descending=True)
    r.finish()

    r=Report('Daily_Financial','Daily Financial','#1F7F64')
    r.start('financial','Tài chính theo ngày','Tổng hợp Yellow / Green / HVFHV',note+' Không có tài chính FHV. Tổng tiền khách trả không đồng nghĩa lợi nhuận.',date='Snapshot Date')
    r.cards([('Số chuyến có tài chính','Daily Financial Snapshot TotalTrips'),('Tiền khách trả · USD','Daily Financial Snapshot TotalPassengerCharges'),('Tiền tip · USD','Daily Financial Snapshot TotalTips'),('Tiền tài xế · USD','Daily Financial Snapshot TotalDriverPay')])
    r.chart('lineChart','Tiền khách trả theo ngày · USD',('Snapshot Date','Full Date'),['Daily Financial Snapshot TotalPassengerCharges'],24,338,legend=('Dim Service Type','Service Code'))
    r.chart('clusteredColumnChart','Số chuyến theo dịch vụ',('Dim Service Type','Service Code'),['Daily Financial Snapshot TotalTrips'],728,338)
    r.chart('clusteredColumnChart','Tiền tip và thuế/phí theo dịch vụ · USD',('Dim Service Type','Service Code'),['Daily Financial Snapshot TotalTips','Daily Financial Snapshot TotalTaxesAndFees'],24,610)
    r.chart('lineChart','Tiền tài xế theo ngày · USD',('Snapshot Date','Full Date'),['Daily Financial Snapshot TotalDriverPay'],728,610)
    r.finish()

    r=Report('Zone_Traffic','Zone Traffic','#2765A8')
    r.start('traffic','Nhu cầu theo khu vực','So sánh lưu lượng dịch vụ • giờ cao điểm • quận',note+' Lượt đón và trả là hai sự kiện; không cộng chúng thành tổng chuyến.',date='Snapshot Date',extra=('Quận',('Snapshot Location','Borough')))
    # This cube exposes only two measures; do not invent cross-cube KPI or averages.
    r.visual('card','Lượt đón',24,210,688,110,{'Values':[r.mea('Zone Traffic Snapshot TotalPickups')]})
    r.visual('card','Lượt trả',728,210,688,110,{'Values':[r.mea('Zone Traffic Snapshot TotalDropoffs')]})
    r.chart('lineChart','Lượt đón theo ngày và dịch vụ',('Snapshot Date','Full Date'),['Zone Traffic Snapshot TotalPickups'],24,338,legend=('Dim Service Type','Service Code'))
    r.chart('clusteredColumnChart','Lượt đón theo giờ và dịch vụ',('Snapshot Time','Hour Number'),['Zone Traffic Snapshot TotalPickups'],728,338,legend=('Dim Service Type','Service Code'))
    r.chart('clusteredBarChart','Lượt đón và trả theo quận',('Snapshot Location','Borough'),['Zone Traffic Snapshot TotalPickups','Zone Traffic Snapshot TotalDropoffs'],24,610,descending=True)
    r.chart('clusteredColumnChart','Lưu lượng đã nạp theo dịch vụ',('Dim Service Type','Service Code'),['Zone Traffic Snapshot TotalPickups'],728,610)
    r.start('traffic_detail','Chi tiết không gian & giờ','Ma trận lưu lượng quận × giờ và phân bổ theo zone',note+' Ma trận giữ Unknown. Đọc số lượt theo cùng bộ lọc; không cộng vào số chuyến chi tiết.',date='Snapshot Date',extra=('Quận',('Snapshot Location','Borough')))
    r.visual('card','Lượt đón',24,210,688,110,{'Values':[r.mea('Zone Traffic Snapshot TotalPickups')]})
    r.visual('card','Lượt trả',728,210,688,110,{'Values':[r.mea('Zone Traffic Snapshot TotalDropoffs')]})
    r.visual('pivotTable','Lượt đón theo quận × giờ',24,338,688,528,{
        'Rows':[r.col('Snapshot Location','Borough')],
        'Columns':[r.col('Snapshot Time','Hour Number')],
        'Values':[r.mea('Zone Traffic Snapshot TotalPickups')]})
    r.chart('clusteredBarChart','Lượt đón theo khu vực · cuộn để xem đủ zone',('Snapshot Location','Zone Name'),['Zone Traffic Snapshot TotalPickups'],728,338,688,528,descending=True)
    r.finish()

    r=Report('Base_Performance','Base Performance','#AC5C32')
    r.start('base','Hiệu suất điều phối','Base • thời gian chờ • yêu cầu đi chung',note+' Không dùng WAV Match Rate làm tỷ lệ đáp ứng; định nghĩa tử/mẫu chưa được xác nhận.',date='Snapshot Date',extra=('Base',('Dispatch Base','Base Key')))
    r.cards([('Số chuyến','Base Performance Snapshot TotalTrips'),('Thời lượng TB · phút','Base Average Duration Minutes'),('Chờ TB · phút','Base Average Waiting Minutes'),('Tỷ lệ yêu cầu đi chung','Shared Request Rate')])
    r.chart('clusteredBarChart','Số chuyến theo base',('Dispatch Base','Base Key'),['Base Performance Snapshot TotalTrips'],24,338,descending=True)
    r.chart('clusteredBarChart','Thời gian chờ theo base · phút',('Dispatch Base','Base Key'),['Base Average Waiting Minutes'],728,338,descending=True)
    r.chart('lineChart','Số chuyến theo ngày và dịch vụ',('Snapshot Date','Full Date'),['Base Performance Snapshot TotalTrips'],24,610,legend=('Dim Service Type','Service Code'))
    r.chart('clusteredBarChart','Yêu cầu đi chung theo nhà cung cấp',('Dim HVFHS Provider','License Number'),['Shared Request Rate'],728,610,descending=True)
    r.finish()
    # SSAS exposes grouped caption columns: test with their hidden grouping keys too.
    for check in CHECKS:
        check['groupBy']=[]
        if check['measure']:continue
        tree=E.parse(str(ROOT/'metadata'/f'{check["cube"]}.csdl.xml'))
        for table in tree.findall('./'+ED+'EntityType'):
            # ReferenceName can contain spaces while the CSDL identifier has underscores.
            entity=next((s for s in tree.findall('.//'+ED+'EntitySet') if s.get('Name')==table.get('Name')),None)
            if entity is None:continue
            ann=entity.find(BI+'EntitySet');tn=ann.get('ReferenceName',entity.get('Name')) if ann is not None else entity.get('Name')
            if tn!=check['table']:continue
            props={p.get('Name'):p for p in table.findall(ED+'Property')}
            for p in props.values():
                ann=p.find(BI+'Property')
                if ann is not None and ann.get('ReferenceName',p.get('Name'))==check['property']:
                    for key in ann.findall('./'+BI+'GroupBy/'+BI+'PropertyRef'):
                        kp=props[key.get('Name')];ka=kp.find(BI+'Property')
                        check['groupBy'].append(ka.get('ReferenceName',kp.get('Name')) if ka is not None else kp.get('Name'))
    dump(ROOT/'report-index.json',INDEX);dump(ROOT/'field-bindings.json',CHECKS)
    print(f'Created {len(INDEX)} live projects, {sum(len(x["pages"]) for x in INDEX)} pages, {len(CHECKS)} field bindings')

if __name__=='__main__':main()


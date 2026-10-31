from pathlib import Path
from lxml import etree as E
import urllib.request
url='https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx2/066e404d-ddcb-438b-9588-ff67184234c8'
data=urllib.request.urlopen(url,timeout=30).read()
r=E.HTML(data)
blocks=r.xpath('//pre')
for p in blocks:
 text=p.xpath('string(.)').replace('\xa0',' ').strip()
 if '<xs:schema' in text:
  Path('etl/dtsx2-2014-reference.xsd').write_text(text,encoding='utf-8')
  x=E.fromstring(text.encode());print('Saved official schema:',len(text),'bytes')
  for name in ['PackageParameterType','PrecedenceConstraintType','EventHandlerType','BasePropertyAttributeGroup']:
   found=x.xpath('//*[@name=$n]',n=name)
   if found: print(E.tostring(found[0]).decode()[:1600])
  break
else:print('No embedded schema in reference page')

"""Preserve package source and repair only missing OnError LoggingOptions."""
from pathlib import Path
from lxml import etree as E
import sys, shutil
D='{www.microsoft.com/SqlServer/Dts}'
for p in Path(sys.argv[1]).glob('*.dtsx'):
    tree=E.parse(str(p));changed=False
    for h in tree.findall('.//'+D+'EventHandler'):
        if h.find(D+'LoggingOptions') is None:
            if not changed and not (Path(sys.argv[2])/p.name).exists():shutil.copy2(p,Path(sys.argv[2])/p.name)
            e=E.Element(D+'LoggingOptions');e.set(D+'LoggingMode','0')
            x=h.find(D+'Executables');h.insert(list(h).index(x) if x is not None else len(h),e);changed=True
    if changed:
        tree.write(str(p),encoding='utf-8',xml_declaration=True)
        print('Repaired LoggingOptions only:',p.name)

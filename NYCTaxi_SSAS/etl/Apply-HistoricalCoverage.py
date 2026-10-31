"""Apply the documented TLC publication start dates to staging coverage validation."""
from pathlib import Path
from lxml import etree as E

OLD = "FROM (VALUES ('yellow'), ('green'), ('fhv'), ('fhvhv')) AS D(DatasetCode);"
NEW = """FROM (VALUES ('yellow',CONVERT(date,'20090101')), ('green',CONVERT(date,'20130801')),
        ('fhv',CONVERT(date,'20150101')), ('fhvhv',CONVERT(date,'20190201'))) AS D(DatasetCode,FirstMonth)
    WHERE @Month >= D.FirstMonth;"""

def apply(path):
    doc = E.parse(str(path))
    name = '{www.microsoft.com/sqlserver/dts/tasks/sqltask}SqlStatementSource'
    changed = 0
    for node in doc.iter():
        sql = node.get(name)
        if sql and OLD in sql:
            node.set(name, sql.replace(OLD, NEW))
            changed += 1
    if changed:
        doc.write(str(path), encoding='utf-8', xml_declaration=True)
    elif NEW not in path.read_text(encoding='utf-8'):
        # XML may escape characters, so inspect parsed attribute values.
        assert any(NEW in (n.get(name) or '') for n in doc.iter()), 'Coverage SQL not found'

if __name__ == '__main__':
    apply(Path(__file__).parent / 'packages/PKG_01_Extract_Stage.dtsx')

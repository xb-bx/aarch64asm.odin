#!/bin/python
import lxml.etree as ET
import itertools
import sys
import json
from types import SimpleNamespace

def striptonone(x):
    if x is None or x.strip() == "": 
        return None
    if x == "x": return "0"
    return x.strip()



root = ET.parse(sys.argv[1]).getroot()
instr_id = root.attrib['id']
regdiagram = root.xpath('//regdiagram')[0]
opcode_bin = ''
for i in regdiagram:
    width = int(i.attrib.get('width', '1'))
    opcode_bin += str.join('', list(map(lambda y: (striptonone(y.text) or "0") * int(y.attrib.get('colspan') or '1'), i)))

def all(f, x):
    for i in x:
        if not f(i): return False
    return True

def boxtofield(i):
    width = int(i.attrib.get('width', '1'))
    hibit = int(i.attrib.get('hibit'))
    start = hibit - width + 1
    name = i.attrib['name']
    if name == 'opc':
        width = 1
        name = 'sf'
    return SimpleNamespace(name=name, start=start, width=width)
def checkshift(x, xml):
    count = int(xml.xpath("count(//definition[@encodedin='shift']//row)"))
    if count == 4:
        x.name = "shiftbool"

opcode = int(opcode_bin, 2)
fields = []
for box in regdiagram:
    if all(lambda c: striptonone(c.text) == None, box):
        fld = boxtofield(box)
        if fld.name == 'shift': checkshift(fld, root)
        if fld.name == 'S': 
            fld.name = 'shiftbool'
        fields.append(fld)

def first(x, f):
    for i in x:
        if f(i):
            return i
    return None
def checklabel(fields, xml):
    ac = xml.xpath("//symbol[@link='label']/following-sibling::account[1]")
    if len(ac) != 0: 
        f = first(fields, lambda fld: fld.name == ac[0].attrib['encodedin'])
        f.name = "label"
checklabel(fields, root)
for field in fields:
    if field.name.startswith('imm'): field.name = 'imm'

priorities = [
    'sf',
    'Rd',
    'Rt',
    'Rn',
    'Rm',
    'cond',
    'shift',
    'label',
    'imm',
    'shiftbool',
    'option',
    'hw',
]
sortedfields = []
for prio in priorities:
    for fld in fields:
        if fld.name == prio:
            sortedfields.append(fld)
            fields.remove(fld)
            break
if len(fields) != 0:
    print(fields)
    sys.exit(1)

mnemonic = root.xpath('//docvar[@key="mnemonic"]')[0].attrib['value']
res = root.xpath('//docvar[@key="alias_mnemonic"]')
if len(res) != 0:
    mnemonic = res[0].attrib['value']


json.dump(SimpleNamespace(id=instr_id,opcode=opcode,fields=sortedfields,mnemonic=mnemonic), default=vars, fp=sys.stdout)


#!/usr/bin/env python
import lxml.etree as ET
import itertools
import sys
import json
from types import SimpleNamespace

root: ET._Element = ET.parse(sys.argv[1]).getroot()
mnemonic = root.xpath('//docvar[@key="mnemonic"]')[0].attrib['value']
instr_id = root.attrib['id']
res = root.xpath('//docvar[@key="alias_mnemonic"]')
if len(res) != 0:
    mnemonic = res[0].attrib['value']
priorities = [
    'sf',
    'opc',
    'type',
    'Rd',
    'Rt',
    'Rn',
    'Rm',
    'cond',
    'shift',
    'option',
    'label',
    'imm',
    'shiftbool',
    'S',
    'hw',
]
def findfld(fields, name):
    i = 0
    for fld in fields:
        if fld.name == name: return (fld, i)
        i = i + 1
def copy_fields(fields):
    res = []
    for fld in fields:
        res.append(SimpleNamespace(**vars(fld)))
    return res
def type_field(field, enc_name):
    global root
    if field.name[0] == 'R':
        field.type = root.xpath(f"//explanation[contains(@enclist,'{enc_name}')]/symbol[following-sibling::account[@encodedin='{field.name}']]")[0].attrib['link'][0]
        delattr(field, 'val')
    elif field.name.startswith('imm'):
        r = root.xpath(f"//symbol[@link='label']/following-sibling::account[@encodedin='{field.name}'][1]")
        if len(r) != 0:
            field.type = 'label'
            field.name = 'label'
    elif field.name == 'shift':
        count = int(root.xpath("count(//definition[@encodedin='shift']//row)"))
        if count == 4:
            field.name = "shiftbool"
def sort_fields(fields):
    sortedfields = []    
    for prio in priorities:
        for fld in fields:
            if fld.name == prio or (fld.name.startswith('imm') and prio == 'imm'):
                sortedfields.append(fld)
                fields.remove(fld)
                break

    if len(fields) != 0:
        print(fields)
        sys.exit(1)
    return sortedfields
    
def parse_encoding(enc: ET._Element, base_opcode, base_fields):
    boxes = enc.xpath('box')
    enc_fields = copy_fields(base_fields)
    opcode = base_opcode
    enc_name = enc.attrib['name']
    for box in boxes:
        name = box.attrib['name']
        (field, i) = findfld(enc_fields, name)
        ci = 0
        bef = field.val
        for c in box:
            if c.text != None:
                cs = list(field.val)
                cs[ci] = c.text.strip()
                if cs[ci] == 'Z' or cs[ci] == 'N': cs[ci] = '0'
                field.val = str.join("", cs)
            ci += 1 
        enc_fields.pop(i)
        opcode = opcode | (int(field.val,2) << field.start)
    for field in enc_fields:
        type_field(field, enc_name)

    enc_fields = sort_fields(enc_fields)
    return SimpleNamespace(name=enc_name, opcode=opcode, fields=enc_fields)


def parse_class(cls: ET._Element, len_classes):
    global root, instr_id
    fields = []
    boxes = cls.xpath('regdiagram/box')
    base_opcode_str = ''
    base_opcode = 0
    for box in boxes:
        name = box.attrib.get('name')
        width = int(box.attrib.get('width', '1'))
        hibit = int(box.attrib['hibit'])
        start = hibit - width + 1
        append = False
        fieldval = ''
        for c in box:
            colspan = int(c.attrib.get('colspan', '1'))
            text = c.text 
            if text == None: append = True
            if text != None: text = c.text.strip()
            else: text = '0'
            if text == 'x':
                text = '0'
                append = True
            elif text == 'Z' or text == 'N':
                text = '0'
            if name != None:
                if c.attrib.get('colspan') != None:
                    append = True
                fieldval += text*colspan
            base_opcode_str += text*colspan
        if append: 
            fields.append(SimpleNamespace(name=name, width=width, start=start, val=fieldval))
    base_opcode = int(base_opcode_str, 2)
    encs = []
    for enc in cls.xpath('encoding'):
        encs.append(parse_encoding(enc, base_opcode, fields))
    name = instr_id
    if len_classes != 1: name = cls.attrib['name']
    if name == 'Post-index': name = 'post'
    if name == 'Pre-index': name = 'pre'
    if name == 'Unsigned offset': name = 'unsigned_off'
    return SimpleNamespace(name=name,encodings=encs)
classes = root.xpath('//iclass')
res = []
for cls in classes:
    res.append(parse_class(cls, len(classes)))

res = SimpleNamespace(mnemonic=mnemonic, classes=res)
json.dump(res, fp=sys.stdout, default=vars, indent=True)
# print(res)
    


sys.exit(0)


# boxes: list[ET._Element] = root.xpath('(//regdiagram)[1]/box')
# base_opcode_str = ''
# base_opcode = 0
# fields = []
#
#
#
#
# base_opcode = int(base_opcode_str, 2)
#
#
# encodings = root.xpath('//encoding')
# boxes = encodings[0].xpath('box')
# if len(boxes) == 0:
#
#
#     for field in fields:
#         type_field(field)
#     sortedfields = []    
#     for prio in priorities:
#         for fld in fields:
#             if fld.name == prio or (fld.name.startswith('imm') and prio == 'imm'):
#                 sortedfields.append(fld)
#                 fields.remove(fld)
#                 break
#
#     if len(fields) != 0:
#         print(fields)
#         sys.exit(1)
#     fields = sortedfields
#     v = SimpleNamespace(name=instr_id, opcode=base_opcode, fields=fields)
#     res = SimpleNamespace(mnemonic=mnemonic, variants=[v])
#     json.dump(res, fp=sys.stdout, default=vars)
#     sys.exit(0)
#
#
# variants = []
# result = [] 
# priorities = [
#     'sf',
#     'opc',
#     'type',
#     'Rd',
#     'Rt',
#     'Rn',
#     'Rm',
#     'cond',
#     'shift',
#     'label',
#     'imm',
#     'shiftbool',
#     'S',
#     'option',
#     'hw',
# ]
#
# # for enc in encodings:
#
# res = SimpleNamespace(mnemonic=mnemonic, variants=result)
# json.dump(res, fp=sys.stdout, default=vars)

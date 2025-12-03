#!/usr/bin/env python
import lxml.etree as ET
import itertools
import sys
import json
import re
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
    'Rt2',
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
    offset_type = enc.xpath('docvars/docvar[@key="offset-type"]')
    offset_info = None
    if len(offset_type) == 1:
        res = re.match(r"off([0-9]+)([su])_([su])", offset_type[0].attrib['value'])
        if res != None:
            size, signed, scaled = res.groups()
            size = int(size)
            signed = signed == 's'
            scaled = scaled == 's'
            offset_info = SimpleNamespace(size=size, scaled=scaled, signed=signed)
    enc_fields = copy_fields(base_fields)
    opcode = base_opcode
    enc_name = enc.attrib['name']
    for box in boxes:
        name = box.attrib['name']
        (field, i) = findfld(enc_fields, name)
        ci = 0
        bef = field.val
        do_pop = True
        for c in box:
            if c.text != None:
                cs = list(field.val)
                cs[ci] = c.text.strip()
                if cs[ci] == 'Z':
                    cs[ci] = '0'
                    field.start += 1
                    field.width -= 1
                elif cs[ci] == 'N': 
                    cs[ci] = '0'
                    do_pop = False
                field.val = str.join("", cs)
            ci += 1 
        if do_pop: enc_fields.pop(i)
        opcode = opcode | (int(field.val,2) << field.start)
    for field in enc_fields:
        type_field(field, enc_name)

    enc_fields = sort_fields(enc_fields)
    return SimpleNamespace(name=enc_name, opcode=opcode, fields=enc_fields, offset_info=offset_info)


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
            elif text == 'Z':
                text = '0'
            elif text == 'N':
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
    if name == 'Signed offset': name = 'signed_off'
    is_mem = findfld(fields, "Rt") != None
    # print(encs)
    if is_mem:
        rm = findfld(fields, "Rm")
        if rm != None:
            new_encs = [] 
            for enc in encs:
                new_encs.append(enc)
                new_enc_fields = copy_fields(enc.fields)
                (rm, rmi) = findfld(new_enc_fields, "Rm")
                if rm.type == 'x': continue
                # print(new_enc_fields, sys.argv[1])
                opt = findfld(new_enc_fields, "option")
                if opt == None: continue
                prevopt = findfld(new_enc_fields, "option")
                (option, optioni) = opt
                (prevoption, prevoptioni) = prevopt
                prevoption.start += 1
                enc.fields[prevoptioni] = prevoption
                if option.width == 2: continue
                rm.type = 'x'
                if option.start < 10 or option.start > 20: print('aboba')
                new_opcode = enc.opcode | (1 << (option.start ))
                # print('start', option.start, hex(base_opcode))
                opt = findfld(new_enc_fields, "option")
                # print(fields)
                if opt != None:
                    (_, optioni) = opt
                    new_enc_fields.pop(optioni)
                new_encs.append(SimpleNamespace(name=enc.name + "_64", opcode=new_opcode, fields=new_enc_fields))
            encs = new_encs

    return SimpleNamespace(name=name,encodings=encs, is_mem=is_mem)
classes = root.xpath('//iclass')
res = []
for cls in classes:
    res.append(parse_class(cls, len(classes)))

res = SimpleNamespace(mnemonic=mnemonic, classes=res)
json.dump(res, fp=sys.stdout, default=vars, indent=True)
    


sys.exit(0)

package gen
import "core:encoding/json"
import "core:math"
import "core:strconv"
import "core:strings"
import "core:fmt"
import "core:io"
import "core:bufio"
import "core:os"
Field :: struct {
    name  : string,
    width : int,
    start : int,
    type  : string,
}
Class :: struct {
    name: string,
    encodings: []Variant,
}
Variant :: struct {
    name   : string,
    opcode : int,
    fields : []Field,
}

Instruction :: struct {
    mnemonic : string,
    classes: []Class,
}

read_line :: proc(reader: ^bufio.Reader) -> (string, bool) {
    l, b := bufio.reader_read_string(reader, '\n')
    l = strings.trim_space(l)
    return l, b == .None
}
atoi :: proc(s: string) -> int {
    v, _ := strconv.parse_int(s)
    return v
}
ones := "1111111111111111111111111111111111111111111111111";
generate_instruction :: proc(instr: Instruction, dir: string, mnemonics: ^map[string][dynamic]string) {
    name := fmt.aprintf("%s/%s.gen.odin", dir, instr.classes[0].encodings[0].name)
    fd, err := os.open(name, os.O_CREATE | os.O_TRUNC | os.O_WRONLY, 0o644)
    fmt.fprintln(fd, "package aarch64")
    fmt.fprintln(fd, "@private")
    prevtype := ""
    for class in instr.classes {
        mnemonic := instr.mnemonic
        if len(instr.classes) != 1 {
            mnemonic = fmt.aprintf("%s_%s", mnemonic, class.name)
        }
        fmt.println(mnemonic)
        if i, ok := mnemonics[instr.mnemonic]; !ok {
            mnemonics[mnemonic] = make([dynamic]string)
        }
        for variant in class.encodings {
            append(&mnemonics[mnemonic], variant.name)
            fmt.fprintf(fd, "%s :: #force_inline proc(a: ^Assembler,", variant.name)
            for fld in variant.fields {
                type := fld.type    
                name := fld.name
                if strings.starts_with(fld.name, "imm") {
                    type = "i32 = 0"
                } else if fld.name == "shift" {
                    type = "Shift"
                } else if fld.name == "shiftbool" || fld.name == "S" {
                    type = "bool = false"
                } else if strings.starts_with(fld.name, "R") {
                    switch fld.type {
                    case "w":
                        type = "WReg"
                    case "x":
                        type = "XReg"
                    case "s":
                        type = "SReg"
                    case "d":
                        type = "DReg"
                    case "h":
                        type = "HReg"
                    case "v":
                        type = "VReg"
                    case "b":
                        type = "BReg"
                    case "q":
                        type = "QReg"
                    case "m":
                        type = prevtype
                        if prevtype == "" do fmt.println(instr)
                    case:
                        fmt.println(fld, instr)
                        panic(type)
                    }
                    prevtype = type
                } else if strings.starts_with(fld.name, "imm") {
                    type = "i32 = 0"
                } else if strings.starts_with(fld.name, "option") {
                    type = "Extend"
                } else if strings.starts_with(fld.name, "label") {
                    type = "Label"
                } else if strings.starts_with(fld.name, "cond") {
                    type = "Cond"
                } else if strings.starts_with(fld.name, "hw") {
                    type = "i8 = 0"
                } else {
                    fmt.println(fld)
                    fmt.println(variant.fields, instr.mnemonic)
                    panic("todo")
                }
                fmt.fprintf(fd, "%s: %s, ", name, type)
            }
            fmt.fprintln(fd, ") {")
            fmt.fprintfln(fd, "result: u32 = 0x%4X", variant.opcode)
            for fld in variant.fields {
                if fld.name == "label" {
                        fmt.fprintfln(fd, "append(&a.labelplaces, Labelplace {{ %s.id, len(a.bytes), %i, %i })", fld.name, fld.start, fld.width) 
                } else {
                    fmt.fprintfln(fd, "result |= ((u32(%s) & 0b%s) << %i)", fld.name, ones[:fld.width], fld.start)
                }
            }
            fmt.fprintln(fd, "append(&a.bytes, result)")
            fmt.fprintln(fd, "}")
        }
    }
} 
main :: proc() {
    data, ok := os.read_entire_file(os.args[1])
    if !ok do os.exit(1)
    instrs: []Instruction = nil
    err := json.unmarshal(data, &instrs)
    assert(err == nil)
    mnemonics := make(map[string][dynamic]string)
    for &instr in instrs {
        generate_instruction(instr, os.args[2], &mnemonics)
    }
    for k, v in mnemonics {
        if len(v) == 0 do continue
        name := fmt.aprintf("%s/%s.gen.odin", os.args[2], strings.to_lower(k))
        fd, er := os.open(name, os.O_CREATE | os.O_TRUNC | os.O_WRONLY, 0o644)
        defer os.close(fd)
        fmt.fprintln(fd, "package aarch64")
        fmt.fprintfln(fd, "%s :: proc {{ ", strings.to_lower(k))
        for i in v {
            fmt.fprintfln(fd, "%s,", i)
        }
        fmt.fprintln(fd, "}")
    }
    fmt.println(mnemonics)
}

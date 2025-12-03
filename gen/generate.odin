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
    is_mem: bool,
}
OffsetInfo :: struct {
    size: int,
    scaled: bool,
    signed: bool,
}
Variant :: struct {
    name   : string,
    opcode : int,
    fields : []Field,
    offset_info: OffsetInfo,
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
    prevtype := ""
    for class in instr.classes {
        mnemonic := instr.mnemonic
        if len(instr.classes) != 1 {
            // mnemonic = fmt.aprintf("%s_%s", mnemonic, class.name)
        }
        fmt.println(mnemonic)
        if i, ok := mnemonics[instr.mnemonic]; !ok {
            mnemonics[mnemonic] = make([dynamic]string)
        }
        for variant in class.encodings {
            fmt.fprintln(fd, "@private")
            fmt.fprintf(fd, "%s :: #force_inline proc(a: ^Assembler,", variant.name)
            if class.is_mem {
                append(&mnemonics[mnemonic], variant.name)
                rt := Field {}
                rt2 := Field {}
                rn := Field {}
                rm := Field {}
                imm := Field {}
                s := Field {}
                option := Field {}
                for fld in variant.fields {
                    if fld.name == "Rt" do rt = fld
                    if fld.name == "Rt2" do rt2 = fld
                    else if fld.name == "Rn" do rn = fld
                    else if fld.name == "Rm" do rm = fld
                    else if fld.name == "S" do s = fld
                    else if fld.name == "option" do option = fld
                    else if strings.starts_with(fld.name, "imm") do imm = fld
                }
                rttype := ""
                switch rt.type {
                case "w":
                    rttype = "WReg"
                case "x":
                    rttype = "XReg"
                case "b":
                    rttype = "BReg"
                case "h":
                    rttype = "HReg"
                case "s":
                    rttype = "SReg"
                case "d":
                    rttype = "DReg"
                case "v":
                    rttype = "VReg"
                case "q":
                    rttype = "QReg"
                case:
                    panic(rt.type)
                }
                fmt.fprint(fd, "Rt:", rttype, ",")
                if rt2.name != "" do fmt.fprint(fd, "Rt2:", rttype, ",")
                mem_type := ""
                if class.name == "post" {
                    mem_type = "MemoryLocationRegImmPost"
                } else if class.name == "pre" {
                    mem_type = "MemoryLocationRegImmPre"
                } else if class.name == "unsigned_off" {
                    mem_type = "MemoryLocationRegUnsignedImm"
                } else if class.name == "signed_off" {
                    mem_type = "MemoryLocationRegSignedImm"
                } else {
                    switch rm.type {
                    case "w":
                        mem_type = "MemoryLocationRegReg32"
                    case "x":
                        mem_type = "MemoryLocationRegReg64"
                    case:
                        fmt.println(variant)
                        panic(rm.type)
                    }
                }
                scale := rt.type == "x" ? 3 : 2 
                fmt.fprintln(fd, "mem:", mem_type, ") {")
                fmt.fprintfln(fd, "result: u32 = 0x%4X", variant.opcode)
                fmt.fprintfln(fd, "result |= ((u32(Rt) & 0b%s) << %i)", ones[:rt.width], rt.start)
                if rt2.name != "" do fmt.fprintfln(fd, "result |= ((u32(Rt2) & 0b%s) << %i)", ones[:rt2.width], rt2.start)
                if class.name == "post" || class.name == "pre" {
                    fmt.fprintfln(fd, "result |= ((u32(mem.reg) & 0b%s) << %i)", ones[:rn.width], rn.start)
                    fmt.fprintfln(fd, "result |= ((u32(mem.imm >> %i) & 0b%s) << %i)", variant.offset_info.scaled ? scale : 1, ones[:imm.width], imm.start)
                } else if class.name == "unsigned_off" || class.name == "signed_off" { 
                    fmt.fprintfln(fd, "result |= ((u32(mem.reg) & 0b%s) << %i)", ones[:rn.width], rn.start)
                    fmt.fprintfln(fd, "result |= ((u32(mem.imm >> %i) & 0b%s) << %i)", variant.offset_info.scaled ? scale : 1, ones[:imm.width], imm.start)
                } else {
                    fmt.fprintfln(fd, "result |= ((u32(mem.regbase) & 0b%s) << %i)", ones[:rn.width], rn.start)
                    fmt.fprintfln(fd, "result |= ((u32(mem.regoffset) & 0b%s) << %i)", ones[:rm.width], rm.start)
                    if rm.type == "w" {
                        fmt.fprintfln(fd, "result |= ((u32(mem.shift) & 0b%s) << %i)", ones[:s.width], s.start)
                        fmt.fprintfln(fd, "sx := mem.is_sxtw ? 0b11 : 0b01")
                        fmt.fprintfln(fd, "result |= ((u32(sx) & 0b11) << %i)", option.start)
                    } else {
                        fmt.fprintfln(fd, "result |= ((u32(mem.shift ? 0b011 : 0b010) & 0b111) << %i)", s.start)
                    }
                }
            } else {
                append(&mnemonics[mnemonic], variant.name)
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

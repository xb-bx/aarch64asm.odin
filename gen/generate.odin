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
    name:   string,
    start:  int,
    width:  int,
}

Instruction :: struct {
    id:       string,
    opcode:   u32,      
    fields:   []Field,
    mnemonic: string,
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
    if i, ok := mnemonics[instr.mnemonic]; ok {
        append(&mnemonics[instr.mnemonic], instr.id)
    } else {
        mnemonics[instr.mnemonic] = make([dynamic]string)
        append(&mnemonics[instr.mnemonic], instr.id)
    }
    is_sf := instr.fields[0].name == "sf"
    fd, err := os.open(fmt.aprintf("%s/%s.gen.odin", dir, instr.id), os.O_CREATE | os.O_TRUNC | os.O_WRONLY, 0o644)
    fmt.fprintln(fd, "package aarch64")
    fmt.fprintf(fd, "%s :: #force_inline proc(a: ^Assembler,", instr.id)
    flds := is_sf ? instr.fields[1:] : instr.fields
    decld := false
    for fld in flds {
        type: string = ""
        name: string = ""
        if fld.name == "shift" {
            name = "shift"
            type = "Shift = .LSL"
        } else if fld.name == "shiftbool" {
            name = "shiftbool"
            type = "bool = false"
        } else if strings.starts_with(fld.name, "R") {
            name = fld.name
            type = is_sf ? decld ? "T" : "$T" : "XReg"
            decld = true
        } else if strings.starts_with(fld.name, "imm") {
            name = fld.name
            type = "i32 = 0"
        } else if strings.starts_with(fld.name, "option") {
            name = fld.name
            type = "Extend"
        } else if strings.starts_with(fld.name, "label") {
            name = fld.name
            type = "Label"
        } else if strings.starts_with(fld.name, "cond") {
            name = fld.name
            type = "Cond"
        } else if strings.starts_with(fld.name, "hw") {
            name = fld.name
            type = "i8 = 0"
        } else {
            fmt.println(fld)
            panic("todo")
        }
        fmt.fprintf(fd, "%s: %s, ", name, type)
    }
    if is_sf {
        fmt.fprintln(fd, ") where T == XReg || T == WReg {")
    } else {
        fmt.fprintln(fd, ") {")
    }
    fmt.fprintfln(fd, "result: u32 = 0x%4X", instr.opcode)
    for fld in flds {
        if fld.name == "label" {
                fmt.fprintfln(fd, "append(&a.labelplaces, Labelplace {{ %s.id, len(a.bytes), %i, %i })", fld.name, fld.start, fld.width) 
        } else {
            fmt.fprintfln(fd, "result |= ((u32(%s) & 0b%s) << %i)", fld.name, ones[:fld.width], fld.start)
        }
    }
    if is_sf {
        fmt.fprintfln(fd, "when T == XReg {{ result |= ((1) << %i) }", instr.fields[0].start)
        // fmt.fprintln(fd, "result |= ((u32(%s) & %i) << %i)", fld.name, fld.width, fld.start)
    }
    fmt.fprintln(fd, "append(&a.bytes, result)")
    fmt.fprintln(fd, "}")

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
        fd, er := os.open(fmt.aprintf("%s/%s.gen.odin", os.args[2], strings.to_lower(k)), os.O_CREATE | os.O_TRUNC | os.O_WRONLY, 0o644)
        fmt.fprintln(fd, "package aarch64")
        fmt.fprintfln(fd, "%s :: proc {{ ", strings.to_lower(k))
        for i in v {
            fmt.fprintfln(fd, "%s,", i)
        }
        fmt.fprintln(fd, "}")
    }
    fmt.println(mnemonics)
}

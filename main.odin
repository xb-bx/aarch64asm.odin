package aarch64
import "core:fmt"
import "core:mem/virtual"
masks: [31]u32 = {
0x1,
0x3,
0x7,
0xf,
0x1f,
0x3f,
0x7f,
0xff,
0x1ff,
0x3ff,
0x7ff,
0xfff,
0x1fff,
0x3fff,
0x7fff,
0xffff,
0x1ffff,
0x3ffff,
0x7ffff,
0xfffff,
0x1fffff,
0x3fffff,
0x7fffff,
0xffffff,
0x1ffffff,
0x3ffffff,
0x7ffffff,
0xfffffff,
0x1fffffff,
0x3fffffff,
0x7fffffff,
}
Label :: struct {
	id:     int,
	offset: int,
}
Labelplace :: struct {
    id: int,
    offset: int,
	start:  int,
	size:   int,
}
Cond :: enum {
	EQ = 0,
	NE,
	CS,
	CC,
	MI,
	PL,
	VS,
	VC,
	HI,
	LS,
	GE,
	LT,
	GT,
	LE,
	AL,
	NV,
}
Assembler :: struct {
	bytes:       [dynamic]u32,
	labels:      [dynamic]Label,
	labelplaces: [dynamic]Labelplace,
	mnemonics:   [dynamic]string,
	remember:    bool,
}
init_asm :: proc(using assembler: ^Assembler, remember_mnemonics: bool = false) {
	bytes = make([dynamic]u32, 0, 128)
	labels = make([dynamic]Label, 0, 16)
	labelplaces = make([dynamic]Labelplace, 0, 16)
	if remember_mnemonics {
		remember = true
		mnemonics = make([dynamic]string)
	}
}

create_label :: proc(using assembler: ^Assembler) -> Label {
	lbl := Label {
		id     = len(labels),
		offset = 0,
	}
	append(&labels, lbl)
	return lbl
}
set_label :: proc(using assembler: ^Assembler, lbl: Label) {
	lbl := &labels[lbl.id]
	lbl.offset = len(bytes)
	if remember {append(&mnemonics, fmt.aprintf("label_%i:", lbl.id))}
}
assemble :: proc(using assebler: ^Assembler) {
	for place in labelplaces {
		lbl := labels[place.id]
		offset := u32((lbl.offset - (place.offset)))
        offset &= masks[place.size - 1]
        offset <<= u32(place.start)
        bytes[place.offset] |= offset
	}

}

HReg :: distinct u8
h :: proc(i: int) -> HReg { return HReg(i) }
SReg :: distinct u8
s :: proc(i: int) -> SReg { return SReg(i) }
DReg :: distinct u8
d :: proc(i: int) -> DReg { return DReg(i) }
XReg :: distinct u8
x :: proc(i: int) -> XReg { return XReg(i) }
WReg :: distinct u8
w :: proc(i: int) -> WReg { return WReg(i) }
VReg :: distinct u8
v :: proc(i: int) -> VReg { return VReg(i) }
QReg :: distinct u8
q :: proc(i: int) -> QReg { return QReg(i) }
BReg :: distinct u8


Extend :: enum {
    UXTB,
    UXTH,
    LSL,
    UXTX,
    SXTB,
    SXTH,
    SXTW,
    SXTX,
}
Shift :: enum {
    LSL,
    LSR,
    ASR,
    ROR,
}
MemoryLocationRegReg32 :: struct {
    regbase: XReg,
    regoffset: WReg,
    is_sxtw: bool,
    shift: bool,
}
MemoryLocationRegReg64 :: struct {
    regbase: XReg,
    regoffset: XReg,
    shift: bool,
}
MemoryLocationRegImmPre :: struct {
    reg: XReg,
    imm: int,
}
MemoryLocationRegImmPost :: struct {
    reg: XReg,
    imm: int,
}
MemoryLocationRegUnsignedImm :: struct {
    reg: XReg,
    imm: uint,
}
MemoryLocationRegSignedImm :: struct {
    reg: XReg,
    imm: int,
}
at_signed :: proc(x: XReg, imm: uint) -> MemoryLocationRegUnsignedImm { return  MemoryLocationRegUnsignedImm { x, imm } }
at_unsigned :: proc(x: XReg, imm: uint) -> MemoryLocationRegUnsignedImm { return  MemoryLocationRegUnsignedImm { x, imm } }

at_imm :: proc(x: XReg, imm: int) -> MemoryLocationRegImmPre { return  MemoryLocationRegImmPre { x, imm, } }
at_post:: proc(x: XReg, imm: int) -> MemoryLocationRegImmPost { return  MemoryLocationRegImmPost { x, imm } }
at_reg32 :: proc(x: XReg, w: WReg, shift2: bool = false, sign_extend: bool = false) -> MemoryLocationRegReg32 {
    return MemoryLocationRegReg32 {x, w, sign_extend, shift2 }
}
at_reg64 :: proc(x: XReg, w: XReg, shift3: bool = false) -> MemoryLocationRegReg64 {
    return MemoryLocationRegReg64 {x, w, shift3 }
}
at :: proc { at_imm, at_reg32, at_reg64, at_unsigned }
compile_fibonacci :: proc(a: ^Assembler) {
    num1 := x(1)
    num2 := x(2)
    next := x(3)
    n := x(0)
    i := x(4)
    mov(a, num1, 0)
    mov(a, num2, 1)
    mov(a, next, 0)
    mov(a, i, 3)

    loop_body := create_label(a)
    loop_cond := create_label(a)
    loop_end := create_label(a)

    set_label(a, loop_cond) 
        cmp(a, i, n, Shift.LSL, 0)
        b(a, Cond.GT, loop_end)
    
    set_label(a, loop_body)
        add(a, next, num1, num2, Shift.LSL)
        mov(a, num1, num2)
        mov(a, num2, next)
        add(a, i, i, 1) 
        b(a, loop_cond)
    set_label(a, loop_end)
        mov(a, x(0), next)
        ret(a, x(30))
}
main :: proc() {
	a: Assembler = {}

	init_asm(&a)
    stp(&a, x(0), x(1), at_imm(x(31), -16))
    // compile_fibonacci(&a)
    // assemble(&a)
    //
    // block, err := virtual.memory_block_alloc(4096, 4096, 32)
    // copy(block.base[:len(a.bytes)*4], (cast([^]u8)&a.bytes[0])[:len(a.bytes)*4])
    // virtual.protect(transmute(rawptr)(transmute(u64)(block.base) & (~u64(0xFFF))), 4096, {.Read, .Write, .Execute})
    //
    // fibonacci := transmute(proc "c" (n1: i64) -> i64)block.base
    //
    // fmt.println(fibonacci(20))
    for b in a.bytes {
        fmt.printfln("%4X", b)
    }
}

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
XReg :: enum {
	X0  = 0,
	X1  = 1,
	X2  = 2,
	X3  = 3,
	X4  = 4,
	X5  = 5,
	X6  = 6,
	X7  = 7,
	X8  = 8,
	X9  = 9,
	X10 = 10,
	X11 = 11,
	X12 = 12,
	X13 = 13,
	X14 = 14,
	X15 = 15,
	X16 = 16,
	X17 = 17,
	X18 = 18,
	X19 = 19,
	X20 = 20,
	X21 = 21,
	X22 = 22,
	X23 = 23,
	X24 = 24,
	X25 = 25,
	X26 = 26,
	X27 = 27,
	X28 = 28,
	X29 = 29,
	X30 = 30,
}
WReg :: enum {
	W0  = 0,
	W1  = 1,
	W2  = 2,
	W3  = 3,
	W4  = 4,
	W5  = 5,
	W6  = 6,
	W7  = 7,
	W8  = 8,
	W9  = 9,
	W10 = 10,
	W11 = 11,
	W12 = 12,
	W13 = 13,
	W14 = 14,
	W15 = 15,
	W16 = 16,
	W17 = 17,
	W18 = 18,
	W19 = 19,
	W20 = 20,
	W21 = 21,
	W22 = 22,
	W23 = 23,
	W24 = 24,
	W25 = 25,
	W26 = 26,
	W27 = 27,
	W28 = 28,
	W29 = 29,
	W30 = 30,
}
w0 :: WReg.W0
w1 :: WReg.W1
w2 :: WReg.W2
w3 :: WReg.W3
w4 :: WReg.W4
w5 :: WReg.W5
w6 :: WReg.W6
w7 :: WReg.W7
w8 :: WReg.W8
w9 :: WReg.W9
w10 :: WReg.W10
w11 :: WReg.W11
w12 :: WReg.W12
w13 :: WReg.W13
w14 :: WReg.W14
w15 :: WReg.W15
w16 :: WReg.W16
w17 :: WReg.W17
w18 :: WReg.W18
w19 :: WReg.W19
w20 :: WReg.W20
w21 :: WReg.W21
w22 :: WReg.W22
w23 :: WReg.W23
w24 :: WReg.W24
w25 :: WReg.W25
w26 :: WReg.W26
w27 :: WReg.W27
w28 :: WReg.W28
w29 :: WReg.W29
w30 :: WReg.W30

x0 :: XReg.X0
x1 :: XReg.X1
x2 :: XReg.X2
x3 :: XReg.X3
x4 :: XReg.X4
x5 :: XReg.X5
x6 :: XReg.X6
x7 :: XReg.X7
x8 :: XReg.X8
x9 :: XReg.X9
x10 :: XReg.X10
x11 :: XReg.X11
x12 :: XReg.X12
x13 :: XReg.X13
x14 :: XReg.X14
x15 :: XReg.X15
x16 :: XReg.X16
x17 :: XReg.X17
x18 :: XReg.X18
x19 :: XReg.X19
x20 :: XReg.X20
x21 :: XReg.X21
x22 :: XReg.X22
x23 :: XReg.X23
x24 :: XReg.X24
x25 :: XReg.X25
x26 :: XReg.X26
x27 :: XReg.X27
x28 :: XReg.X28
x29 :: XReg.X29
x30 :: XReg.X30
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
compile_fibonacci :: proc(a: ^Assembler) {
    num1 := x1
    num2 := x2
    next := x3
    n := x0
    i := x4
    mov(a, num1, 0)
    mov(a, num2, 1)
    mov(a, next, 0)
    mov(a, i, 3)

    loop_body := create_label(a)
    loop_cond := create_label(a)
    loop_end := create_label(a)

    set_label(a, loop_cond) 
        cmp(a, i, n)
        b(a, Cond.GT, loop_end)
    
    set_label(a, loop_body)
        add(a, next, num1, num2)
        mov(a, num1, num2)
        mov(a, num2, next)
        add(a, i, i, 1) 
        b(a, loop_cond)
    set_label(a, loop_end)
        mov(a, x0, next)
        ret(a, x30)
}
main :: proc() {
	a: Assembler = {}

	init_asm(&a)
    compile_fibonacci(&a)
    assemble(&a)

    block, err := virtual.memory_block_alloc(4096, 4096, 32)
    copy(block.base[:len(a.bytes)*4], (cast([^]u8)&a.bytes[0])[:len(a.bytes)*4])
    virtual.protect(transmute(rawptr)(transmute(u64)(block.base) & (~u64(0xFFF))), 4096, {.Read, .Write, .Execute})

    fibonacci := transmute(proc "c" (n1: i64) -> i64)block.base

    fmt.println(fibonacci(20))
}

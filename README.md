# aarch64 assembler for odin developed for my wasm-runtime

## At compilation it parses [ARM's machine readable spec](https://developer.arm.com/-/media/developer/products/architecture/armv8-a-architecture/A64_v82A_ISA_xml_00bet3.1.tar.gz) and generates odin procedures to encode aarch64 instructions

## list of instructions to generate is in [./instructions_to_generate.txt](./instructions_to_generate.txt)


## Example 
```odin
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
```


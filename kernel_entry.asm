[BITS 32]
[GLOBAL _start]
[GLOBAL irq12_stub]
[GLOBAL irq_default_stub]
[EXTERN kmain]
[EXTERN irq12_handler]
[EXTERN irq_default_handler]

section .text

_start:
    cli
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    mov ebp, esp
    call kmain
.halt:
    cli
    hlt
    jmp .halt

irq12_stub:
    pusha
    push ds
    push es
    push fs
    push gs
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    call irq12_handler
    pop gs
    pop fs
    pop es
    pop ds
    popa
    iretd

irq_default_stub:
    pusha
    push ds
    push es
    push fs
    push gs
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    call irq_default_handler
    pop gs
    pop fs
    pop es
    pop ds
    popa
    iretd
[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl
    mov [0x0600], dl

    xor ah, ah
    mov dl, [boot_drive]
    int 0x13

    mov ah, 0x02
    mov al, 17
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x8000
    int 0x13
    jc disk_error

    mov ah, 0x02
    mov al, 15
    mov ch, 0
    mov cl, 1
    mov dh, 1
    mov dl, [boot_drive]
    mov bx, 0xA200
    int 0x13
    jc disk_error

    jmp 0x0000:0x8000

disk_error:
    mov si, err_msg
.print:
    lodsb
    or al, al
    jz .halt
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp .print
.halt:
    cli
    hlt
    jmp .halt

err_msg    db "Disk error!", 0
boot_drive db 0

times 510-($-$$) db 0
dw 0xAA55
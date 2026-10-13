[BITS 16]
[ORG 0x8000]

%define VID     0xB800
%define A_BAR   0x70
%define A_BODY  0x17
%define A_HI    0x1F

start:
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov al, [0x0600]
    mov [boot_drive], al

    call check_installed
    jc .installed

    call show_logo_vga
    call delay_logo

    mov ax, 0x0003
    int 0x10
    xor ax, ax
    mov ds, ax
    mov es, ax
    jmp pg_welcome

.installed:
    call show_logo_vga
    call delay_logo
    jmp run_kernel

show_logo_vga:
    mov ax, 0x0013
    int 0x10
    xor ax, ax
    mov ds, ax
    mov es, ax

    mov si, 0
    mov di, 0
    mov cx, 320
    mov dx, 200
    mov al, 6
    call draw_rect

    mov si, 160
    mov di, 95
    mov bx, 45
    mov al, 5
    call draw_diamond

    mov si, 160
    mov di, 95
    mov bx, 36
    mov al, 6
    call draw_diamond

    mov si, 160
    mov di, 95
    mov bx, 22
    mov al, 5
    call draw_diamond

    mov si, 160
    mov di, 95
    mov bx, 14
    mov al, 6
    call draw_diamond

    mov si, 160
    mov di, 95
    mov bx, 6
    mov al, 1
    call draw_diamond
    ret

draw_diamond:
    mov [dia_cx], si
    mov [dia_cy], di
    mov [dia_r], bx
    mov [dia_col], al
    mov cx, bx
    neg cx
    mov bx, cx
.dy_loop:
    cmp bx, [dia_r]
    jg .done
    mov ax, bx
    test ax, ax
    jns .abs_ok
    neg ax
.abs_ok:
    mov dx, [dia_r]
    sub dx, ax
    mov cx, dx
    add cx, dx
    inc cx
    mov si, [dia_cx]
    sub si, dx
    mov di, [dia_cy]
    add di, bx
    mov dx, 1
    mov al, [dia_col]
    call draw_rect
    inc bx
    jmp .dy_loop
.done:
    ret

dia_cx:  dw 0
dia_cy:  dw 0
dia_r:   dw 0
dia_col: db 0

draw_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov bl, al
    mov bp, dx
    mov ax, di
    xor dx, dx
    mov dx, 320
    mul dx
    add ax, si
    mov di, ax
    mov ax, 0xA000
    mov es, ax
    mov si, cx
    cld
.row:
    mov cx, si
    mov al, bl
    rep stosb
    add di, 320
    sub di, si
    dec bp
    jnz .row
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

delay_logo:
    xor ah, ah
    int 0x1A
    mov bx, dx
    add bx, 18
.wait:
    xor ah, ah
    int 0x1A
    cmp dx, bx
    jb .wait
    ret

print_rm:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp print_rm
.done:
    ret

boot_drive: db 0

check_installed:
    mov ah, 0x02
    mov al, 1
    mov ch, 1137 & 0xFF
    mov cl, 16
    mov dh, 1
    mov dl, [boot_drive]
    mov bx, 0x0500
    push es
    xor ax, ax
    mov es, ax
    int 0x13
    pop es
    jc .no

    mov ax, [0x0500]
    cmp ax, 0xDEAD
    jne .no
    mov ax, [0x0502]
    cmp ax, 0xBEEF
    jne .no

    stc
    ret
.no:
    clc
    ret

; =========================================================
; VESA 1024x768x32 + чтение stride
; =========================================================
set_vesa:
    mov ax, 0x0000
    mov es, ax
    mov di, 0x9000
    mov ax, 0x4F00
    int 0x10
    cmp ax, 0x004F
    jne .no_vbe

        mov ax, 0x4F02
    mov bx, 0x4144
    int 0x10
    cmp ax, 0x004F
    jne .mode_fail

    mov ax, 0x0000
    mov es, ax
    mov di, 0x9000
    mov cx, 0x0144
    mov ax, 0x4F01
    int 0x10
    cmp ax, 0x004F
    jne .mode_fail

    ; LFB base @ offset 40
    mov eax, [0x9000 + 40]
    test eax, eax
    jz .mode_fail
    mov [0x0800], eax

        ; BytesPerScanLine @ offset 16
    mov ax, [0x9000 + 16]
    mov [0x0808], ax

    ; XResolution @ offset 18
    mov ax, [0x9000 + 18]
    mov [0x0804], ax

    ; YResolution @ offset 20
    mov ax, [0x9000 + 20]
    mov [0x0806], ax

    ; BitsPerPixel @ offset 25
    mov al, [0x9000 + 25]
    mov [0x080A], al

    clc
    ret

.no_vbe:
    mov si, msg_no_vbe
    call print_rm
    stc
    ret
.mode_fail:
    mov si, msg_mode_fail
    call print_rm
    stc
    ret

msg_no_vbe:    db "No VBE BIOS!", 0
msg_mode_fail: db "Mode 0x11B failed!", 0

run_kernel:
    call load_kernel
    jc .err

    call set_vesa
    jc .err

    in al, 0x92
    or al, 2
    out 0x92, al

    cli
    lgdt [gdt_desc]

    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pm_entry

.err:
    mov si, msg_err
    call print_rm
.halt:
    cli
    hlt
    jmp .halt

load_kernel:
    mov si, dap
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    ret

dap:
    db 0x10
    db 0
    dw 64
    dw 0x0000
    dw 0x1000
    dq 33

msg_err: db "Kernel load error!", 0

pg_welcome:
    mov al, A_BODY
    call cls
    mov si, s_toptitle
    call topbar
    mov si, s_foot_welc
    call botbar
    mov si, s_wel_h
    mov dl, 4
    call printc
    mov si, s_wel_1
    mov dl, 8
    call printc
    mov si, s_wel_2
    mov dl, 10
    call printc
    mov si, s_wel_3
    mov dl, 13
    call printc
    mov si, s_wel_4
    mov dl, 15
    call printc
    mov si, s_wel_5
    mov dl, 16
    call printc
.k:
    mov ah, 0
    int 0x16
    cmp ah, 0x1C
    je pg_lic
    jmp .k

pg_lic:
    mov al, A_BODY
    call cls
    mov si, s_toptitle
    call topbar
    mov si, s_foot_lic
    call botbar
    mov si, s_lic_h
    mov dl, 4
    call printc
    mov si, s_lic_1
    mov dl, 8
    call printc
    mov si, s_lic_2
    mov dl, 10
    call printc
    mov si, s_lic_3
    mov dl, 12
    call printc
    mov si, s_lic_4
    mov dl, 15
    call printc
    mov si, s_lic_5
    mov dl, 17
    call printc
.k:
    mov ah, 0
    int 0x16
    cmp ah, 0x1C
    je pg_inst
    cmp ah, 0x01
    je pg_welcome
    jmp .k

pg_inst:
    mov al, A_BODY
    call cls
    mov si, s_toptitle
    call topbar
    mov si, s_foot_ok
    call botbar
    mov si, s_inst_h
    mov dl, 6
    call printc
    mov si, s_inst_1
    mov dl, 10
    call printc
    mov si, s_inst_2
    mov dl, 13
    call printc

    mov byte [cur_attr], A_HI
    mov bx, 12
    mov dx, 16
    mov al, '['
    call putch
    mov bx, 55
    mov dx, 16
    mov al, ']'
    call putch

    mov cx, 42
    mov bx, 13
.bar:
    push bx
    push cx
    mov dx, 16
    mov al, 0xDB
    call putch
    call short_delay
    pop cx
    pop bx
    inc bx
    loop .bar

    mov word [0x0500], 0xDEAD
    mov word [0x0502], 0xBEEF
    mov ah, 0x03
    mov al, 1
    mov ch, 1137 & 0xFF
    mov cl, 16
    mov dh, 1
    mov dl, [boot_drive]
    mov bx, 0x0500
    push es
    xor ax, ax
    mov es, ax
    int 0x13
    pop es

    mov si, s_inst_done
    mov dl, 19
    call printc
    mov si, s_inst_reboot
    mov dl, 21
    call printc

    mov ah, 0
    int 0x16
    jmp reboot

reboot:
    mov cx, 100
.wait:
    in al, 0x64
    test al, 2
    jz .go
    loop .wait
.go:
    mov al, 0xFE
    out 0x64, al
    cli
    lidt [null_idt]
    int 3

null_idt:
    dw 0
    dd 0

cls:
    push es
    push di
    push cx
    push bx
    mov ah, al
    mov al, ' '
    mov bx, ax
    mov ax, VID
    mov es, ax
    xor di, di
    mov cx, 2000
    mov ax, bx
    rep stosw
    pop bx
    pop cx
    pop di
    pop es
    ret

putch:
    push es
    push di
    push ax
    push bx
    push dx
    mov ah, 0
    push ax
    mov ax, dx
    mov dx, 80
    mul dx
    pop dx
    add ax, bx
    shl ax, 1
    mov di, ax
    mov ax, VID
    mov es, ax
    mov al, dl
    mov ah, [cur_attr]
    stosw
    pop dx
    pop bx
    pop ax
    pop di
    pop es
    ret

puts:
    push ax
    push bx
    push dx
    push si
.loop:
    lodsb
    test al, al
    jz .done
    call putch
    inc bx
    jmp .loop
.done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

printc:
    push ax
    push bx
    push cx
    push dx
    push si
    push si
    xor cx, cx
.cnt:
    lodsb
    test al, al
    jz .got
    inc cx
    jmp .cnt
.got:
    pop si
    mov ax, 80
    sub ax, cx
    shr ax, 1
    mov bx, ax
    mov byte [cur_attr], A_BODY
    call puts
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

topbar:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax, VID
    mov es, ax
    xor di, di
    mov ah, A_BAR
    mov al, ' '
    mov cx, 80
    rep stosw
    mov byte [cur_attr], A_BAR
    mov bx, 2
    mov dx, 0
    call puts
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

botbar:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax, VID
    mov es, ax
    mov di, 24*80*2
    mov ah, A_BAR
    mov al, ' '
    mov cx, 80
    rep stosw
    mov byte [cur_attr], A_BAR
    mov bx, 2
    mov dx, 24
    call puts
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

short_delay:
    push cx
    push dx
    mov dx, 0x0010
.o:
    mov cx, 0xFFFF
.i:
    loop .i
    dec dx
    jnz .o
    pop dx
    pop cx
    ret

cur_attr: db A_BODY

gdt_start:
    dq 0
gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00
gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00
gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[BITS 32]
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    jmp 0x10000

s_toptitle:     db "OS Setup", 0
s_foot_welc:    db "ENTER=Continue", 0
s_foot_lic:     db "ENTER=I agree   ESC=Back", 0
s_foot_ok:      db "Please wait...", 0

s_wel_h:        db "Welcome to Setup.", 0
s_wel_1:        db "This portion of the Setup program prepares", 0
s_wel_2:        db "the operating system to run on this computer.", 0
s_wel_3:        db "- To set up OS now, press ENTER.", 0
s_wel_4:        db "- To repair, press R.", 0
s_wel_5:        db "- To quit without installing, press F3.", 0

s_lic_h:        db "License Agreement", 0
s_lic_1:        db "Please read the following license agreement.", 0
s_lic_2:        db "By installing this software you accept all", 0
s_lic_3:        db "terms and conditions described below.", 0
s_lic_4:        db "The software is provided AS IS, without", 0
s_lic_5:        db "any warranty, express or implied.", 0

s_inst_h:       db "Installing OS...", 0
s_inst_1:       db "Setup is preparing your system.", 0
s_inst_2:       db "Please wait.", 0
s_inst_done:    db "Setup completed successfully!", 0
s_inst_reboot:  db "Press any key to reboot...", 0

times 16384-($-$$) db 0
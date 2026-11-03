; Console output.
;
; Everything is written with DOS function 40h. Function 09h would stop at a
; '$' and would ignore a redirection made on the command line, so neither the
; interpreter banner nor a string literal could be printed safely with it.

section .text

; console_write_cx -- writes CX bytes at DS:DX to the standard output.
; Returns: CF clear on success, CF set with AX = the DOS error code.
; Clobbers: AX, BX. Preserves: CX, DX, SI, DI, BP.
console_write_cx:
    mov  ah, DOS_WRITE
    mov  bx, DOS_STDOUT
    int  INT_DOS
    ret

; console_print_crlf -- one DOS line break.
; Clobbers: AX, BX. Preserves: CX, DX, SI, DI, BP.
console_print_crlf:
    push cx
    push dx
    mov  dx, CH_CRLF_SLOT
    mov  cx, 2
    call console_write_cx
    pop  dx
    pop  cx
    ret

; console_print_cx_dx -- writes the run at DS:DX and terminates the line.
; Clobbers: nothing visible to the caller.
console_print_cx_dx:
    push ax
    push bx
    push cx
    push dx
    call console_write_cx
    call console_print_crlf
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; console_print_dec -- prints DX as an unsigned decimal number and a line break.
; Clobbers: AX, BX, CX, DI. Preserves: DX, SI, BP.
console_print_dec:
    push dx
    push ax
    push bx
    push cx
    push di
    mov  ax, dx
    xor  cx, cx
    mov  di, DECIMAL_SLOT + 15          ; the digits are built backwards
    mov  bx, 10
.next_digit:
    xor  dx, dx
    div  bx                           ; AX = quotient, DX = remainder
    add  dl, CH_DIGIT_ZERO
    dec  di
    mov  [di], dl
    inc  cx
    test ax, ax
    jnz  .next_digit
    mov  bx, di
    add  bx, cx                       ; BX = just past the last digit
    mov  byte [bx], CH_CR
    mov  byte [bx + 1], CH_LF
    add  cx, 2
    mov  dx, di
    call console_write_cx
    pop  di
    pop  cx
    pop  bx
    pop  ax
    pop  dx
    ret

; console_print_hex4 -- prints AX as four hexadecimal digits, no line break.
; Clobbers: AX, BX, CX, DX, DI. Preserves: SI, BP.
console_print_hex4:
    push ax
    push bx
    push cx
    push dx
    push di
    mov  bx, ax
    mov  cx, 4
    mov  di, HEX4_SLOT
.next_nibble:
    rol  bx, 4                        ; the nibble wanted next ends up low
    mov  dl, bl
    and  dl, 0Fh
    add  dl, CH_DIGIT_ZERO
    cmp  dl, CH_DIGIT_NINE
    jbe  .store_digit
    add  dl, 7                        ; move into the letter range
.store_digit:
    mov  [di], dl
    inc  di
    dec  cx
    jnz  .next_nibble
    mov  dx, HEX4_SLOT
    mov  cx, 4
    call console_write_cx
    pop  di
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

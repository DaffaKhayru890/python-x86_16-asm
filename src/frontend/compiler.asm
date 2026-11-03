; Code generation.
;
; The compiler owns the shape of the threaded stream. A statement becomes one
; handler address followed by the operands that handler expects to read, which
; is why emitting a record and knowing its execution semantics stay together.

section .text

; compiler_emit_print -- appends the PRINT record of the literal just parsed.
; Layout: handler address, offset of the literal, length of the literal.
; Clobbers: AX. Preserves: BX, CX, DX, SI, DI.
compiler_emit_print:
    push bx
    push cx
    push dx
    mov  bx, op_print                  ; a near offset becomes an instruction
    call memory_emit_cell
    jc   err_fatal_thread_overflow
    mov  bx, [g_str_off]
    call memory_emit_cell
    jc   err_fatal_thread_overflow
    mov  bx, [g_str_len]
    call memory_emit_cell
    jc   err_fatal_thread_overflow
    pop  dx
    pop  cx
    pop  bx
    ret

; compiler_finish -- closes the stream with the token that ends a program.
compiler_finish:
    mov  bx, op_halt
    call memory_emit_cell
    jc   err_fatal_thread_overflow
    ret

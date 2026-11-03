; Arena allocation.
;
; The three working areas listed in config.inc are fixed size and are filled by
; a moving cursor. Nothing is ever released, so rewinding the cursors between
; programs is the whole of the management task, and every append has to check
; its own limit.

section .text

; memory_reset -- rewinds the arenas and the lexer position before compiling.
; Clobbers: AX.
memory_reset:
    mov  ax, 0
    mov  [g_src_len], ax
    mov  [g_src_pos], ax
    mov  [g_tok_line], ax
    mov  [g_tok_col], ax
    mov  [g_code_len], ax
    mov  [g_str_len], ax
    mov  [g_str_off], ax
    mov  byte [g_tok], TOK_EOF
    mov  ax, 1
    mov  [g_line], ax
    mov  [g_col], ax
    mov  ax, STRING_BASE
    mov  [g_pool_ptr], ax
    ret

; memory_store_byte -- appends DL to the string pool.
; Returns: CF clear with AX = pool bytes in use, CF set when the pool is full.
; Clobbers: AX, DI. Preserves: BX, CX, DX, SI.
memory_store_byte:
    mov  ax, [g_pool_ptr]
    sub  ax, STRING_BASE              ; AX = bytes of pool already taken
    cmp  ax, MAX_STRING_BYTES
    jae  .full
    mov  di, [g_pool_ptr]
    mov  [di], dl
    inc  di
    mov  [g_pool_ptr], di
    inc  ax                           ; the byte just written is included
    clc
    ret
.full:
    stc
    ret

; memory_emit_cell -- appends BX as one execution token of the stream.
; Returns: CF clear, or CF set when there is no room for the cell.
; Clobbers: AX, DI. Preserves: BX, CX, DX, SI.
memory_emit_cell:
    mov  ax, [g_code_len]
    cmp  ax, MAX_PROGRAM_CELLS
    jae  .full
    mov  di, ax
    add  di, di                       ; cells are two bytes wide
    add  di, CODE_BASE
    mov  [di], bx
    inc  ax
    mov  [g_code_len], ax
    clc
    ret
.full:
    stc
    ret

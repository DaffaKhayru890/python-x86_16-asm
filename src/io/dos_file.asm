; DOS file access.
;
; Only the handle-based functions are used: they report a failure in AX, which
; is what makes the diagnostics of the start-up phase precise.

section .text

; dos_file_open -- opens the ASCIZ name stored at FNAME_BASE for reading.
; Returns: CF clear with AX = the handle, CF set with AX = the DOS error code.
; Clobbers: AX, DX.
dos_file_open:
    mov  ah, DOS_OPEN
    mov  al, DOS_OPEN_READ
    mov  dx, FNAME_BASE
    int  INT_DOS
    jc   .refused
    mov  [g_file_handle], ax
.refused:
    ret

; dos_file_read -- loads the source text into SOURCE_BASE.
; Returns: CF clear with AX = bytes stored.
;          CF set, DX = 0 with AX = the DOS error code.
;          CF set, DX = 1 when the file is larger than the arena.
; Clobbers: AX, BX, CX, DX, DI.
dos_file_read:
    xor  di, di                        ; DI = bytes collected so far
.next_chunk:
    mov  ax, SOURCE_SIZE
    sub  ax, di
    jbe  .test_for_more
    cmp  ax, SOURCE_READ_CHUNK
    jb   .ask_for_the_rest
    mov  ax, SOURCE_READ_CHUNK
.ask_for_the_rest:
    mov  cx, ax
    mov  dx, SOURCE_BASE
    add  dx, di
    mov  bx, [g_file_handle]
    mov  ah, DOS_READ
    int  INT_DOS
    jc   .read_refused
    test ax, ax
    jz   .source_complete
    add  di, ax
    jmp  .next_chunk
.test_for_more:
    mov  cx, 1
    mov  dx, READ_PROBE                ; one byte that is not part of the arena
    mov  bx, [g_file_handle]
    mov  ah, DOS_READ
    int  INT_DOS
    jc   .read_refused
    test ax, ax
    jnz  .source_too_large
.source_complete:
    mov  [g_src_len], di
    mov  ax, di
    clc
    ret
.source_too_large:
    mov  [g_src_len], di
    mov  ax, SOURCE_SIZE
    mov  dx, 1
    stc
    ret
.read_refused:
    xor  dx, dx                        ; AX still carries the DOS error code
    stc
    ret

; dos_file_close -- releases the handle held in g_file_handle.
; Clobbers: AX, BX.
dos_file_close:
    mov  bx, [g_file_handle]
    mov  ah, DOS_CLOSE
    int  INT_DOS
    ret

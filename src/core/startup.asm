; Start-up: welcome banner and the checks that must run before any source is
; read. The segment registers and the stack are already set up by prog_start,
; so this module only prepares state that a routine can own.

section .text

; startup_prepare -- seeds the scratch memory the console layer depends on.
; Clobbers: none.
startup_prepare:
    mov  byte [CH_CRLF_SLOT], CH_CR
    mov  byte [CH_CRLF_SLOT + 1], CH_LF
    call startup_check_arenas
    call startup_greet
    ret

; startup_greet -- names the interpreter before any work is done.
startup_greet:
    push ax
    push bx
    push cx
    push dx
    mov  dx, msg_startup_head
    mov  cx, msg_startup_head_len
    call console_write_cx
    call console_print_crlf
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; startup_show_usage -- banner and usage line for an empty command tail.
startup_show_usage:
    push ax
    push bx
    push cx
    push dx
    mov  dx, msg_need_file
    mov  cx, msg_need_file_len
    call console_write_cx
    call console_print_crlf
    mov  dx, msg_usage
    mov  cx, msg_usage_len
    call console_write_cx
    call console_print_crlf
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; startup_check_arenas -- refuses to run once the image has grown into the
; arenas listed in config.inc, which would otherwise be overwritten silently.
startup_check_arenas:
    push ax
    push bx
    push cx
    push dx
    mov  bx, startup_image_end
    cmp  bx, SOURCE_BASE
    jb   .ok
    mov  dx, msg_arena_overlap
    mov  cx, msg_arena_overlap_len
    call console_print_cx_dx
    jmp  err_fatal_internal
.ok:
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; Direct-threaded dispatch.
;
; The compiled program is a stream of 16-bit cells at CODE_BASE. Every handler
; address is followed by the operands that handler expects, so the handler
; itself decides how many cells it consumes and then jumps back to the loop.
; There is no opcode decoder and no switch: dispatch is one load and one
; indirect jump.
;
; Register convention of the runtime:
;   SI  the threaded instruction pointer, advanced by lodsw
;   AX  the address of the handler being entered
;   BP  counts nested calls, see core/shutdown.asm
;   everything else is scratch for the handler, but must not clobber SI
;
; main.asm checks at build time that the arenas listed in config.inc do not
; overlap, which is what keeps these offsets valid as executable addresses.

section .text

; runtime_run -- executes the stream until the HALT token ends the program.
; Clobbers: AX, SI, DI. Returns through runtime_exit once HALT is reached.
runtime_run:
    push bp
    lea  bp, [bp + 2]
    mov  si, CODE_BASE                    ; SI becomes the instruction pointer
runtime_dispatch:
    lodsw                                 ; AX = address of the next handler
    jmp  ax                               ; thread straight into its code
runtime_exit:
    pop  di                               ; the frame counter of the caller
    mov  ax, di
    add  ax, 2                            ; the frame runtime_run installed
    cmp  ax, bp
    je   .frames_unwound
    mov  dx, msg_stack_imbalance
    mov  cx, msg_stack_imbalance_len
    call console_print_cx_dx
    mov  ax, bp
    call console_print_hex4
    call console_print_crlf
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
.frames_unwound:
    mov  bp, di                           ; the caller gets its counter back
    ret

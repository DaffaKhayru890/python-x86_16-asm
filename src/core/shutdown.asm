; Termination: stack frame check and the exit code handed back to DOS.

section .text

; shutdown_exit -- returns to DOS with the code recorded in g_exit_code.
; Never returns: DOS function 4Ch ends the process.
shutdown_exit:
    call shutdown_check_stack
    mov  al, [g_exit_code]
    mov  ah, DOS_EXIT
    int  INT_DOS

; shutdown_check_stack -- BP counts frames, so the value prog_start installed
; has to be the one still in place when the program ends. Anything else means
; that a routine forgot its pops or wrote past the stack, which is damage inside
; the interpreter rather than a fault of the source program.
; Clobbers: nothing visible to the caller.
shutdown_check_stack:
    push ax
    push bx
    push cx
    push dx
    cmp  bp, STACK_TOP
    je   .balanced
    mov  dx, msg_stack_imbalance
    mov  cx, msg_stack_imbalance_len
    call console_print_cx_dx
    mov  ax, bp
    call console_print_hex4
    call console_print_crlf
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
.balanced:
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; The PRINT handler.
;
; Control arrives here through the indirect jump of the dispatch loop and
; leaves through the same loop, so the handler is entered by an address stored
; in the stream rather than by a call. SI is the threaded instruction pointer
; and has to survive the DOS call that writes the line.

section .text

; op_print -- writes the literal named by the two cells that follow its address.
op_print:
    lodsw                                 ; AX = offset of the literal
    mov  dx, ax
    lodsw                                 ; AX = number of bytes to write
    mov  cx, ax
    push si                               ; keep the thread across the interrupt
    call console_write_cx
    pop  si
    jc   err_fatal_output_refused         ; AX carries the DOS error code
    call console_print_crlf
    jmp  runtime_dispatch

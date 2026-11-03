; The HALT handler.
;
; A compiled program always ends with this address, so the runtime needs no
; length to know where the stream stops and no way to fall off its end.

section .text

; op_halt -- leaves the dispatch loop and returns control to the caller of
; runtime_run, which reports the stack frame and exits.
op_halt:
    jmp  runtime_exit

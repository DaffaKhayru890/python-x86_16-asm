; TinyPrint16 -- entry point and module wiring.
;
; Build from the project root:
;   nasm -f bin -I src -o build/tinyprint16.com src/main.asm
;
; The modules are included in the order they appear in a run: state and text,
; then start-up, input and output, the front end, the threaded runtime and
; finally the reporter that every stage may jump to.

        bits 16

%include "config.inc"

        org COM_ORIGIN

; The entry point has to be the first byte of the image, so this file opens
; .text before the modules do: a "-f bin" build lays the sections out in the
; order they are first declared, and the CPU starts at ORG regardless.
section .text

; prog_start -- the first instruction of the .COM image.
;
; The segments and the stack are repointed here instead of inside a routine.
; A call has already pushed its return address onto the stack that DOS handed
; to the process, so switching SS from within a subroutine would leave that
; address on the old stack and its ret would jump to whatever CS:SP holds.
;
; BP is a frame counter, not a frame pointer: a routine that keeps locals opens
; its frame with push bp plus lea bp, [bp + 2] and closes it with pop bp, so BP
; comes back to STACK_TOP exactly when every frame unwound.
prog_start:
    cli
    mov  ax, cs
    mov  ss, ax
    mov  sp, STACK_TOP
    sti
    mov  ds, ax
    mov  es, ax
    mov  bp, STACK_TOP                       ; origin of the frame counter
    cld                                      ; string instructions move upwards
    call startup_prepare
    call cli_run
    jmp  shutdown_exit

%include "data/buffers.asm"
%include "data/messages.asm"

%include "core/startup.asm"
%include "core/shutdown.asm"
%include "core/memory.asm"

%include "io/console.asm"
%include "io/dos_file.asm"
%include "io/command_line.asm"

%include "frontend/lexer.asm"
%include "frontend/parser.asm"
%include "frontend/compiler.asm"

%include "runtime/threaded_dispatch.asm"
%include "runtime/opcode_print.asm"
%include "runtime/opcode_halt.asm"

%include "errors/error_handler.asm"

; ---------------------------------------------------------------------------
; Layout checks
; ---------------------------------------------------------------------------
; config.inc promises that the arenas sit between the image and the top of the
; segment. These checks turn a broken promise into a build failure instead of a
; program that overwrites its own execution stream.
%macro LAYOUT 2
%if %1 > %2
%error "arena layout in config.inc is wrong: %1 runs into %2"
%endif
%endmacro

        LAYOUT COM_ORIGIN,                   SOURCE_BASE
        LAYOUT STRING_BASE + STRING_SIZE,    CODE_BASE
        LAYOUT CODE_BASE + CODE_SIZE,        IDENT_BASE
        LAYOUT IDENT_BASE + IDENT_SIZE,      FNAME_BASE
        LAYOUT FNAME_BASE + FNAME_SIZE,      SCRATCH_BASE
        LAYOUT SCRATCH_BASE + SCRATCH_SIZE,  STACK_BASE
        LAYOUT STACK_BASE + STACK_SIZE,      0FF00h

; ---------------------------------------------------------------------------
; Program
; ---------------------------------------------------------------------------
section .text

; cli_run -- loads one source file, compiles it, then executes the stream.
; A failure at any stage is handed to errors/error_handler.asm.
cli_run:
    push bp
    lea  bp, [bp + 2]
%ifdef TRACE_STAGES
    mov  dx, dbg_enter
    mov  cx, dbg_enter_len
    call console_print_cx_dx
%endif
    call memory_reset
    call cmd_is_blank_line
    jnz  .name_present
%ifdef TRACE_STAGES
    mov  dx, dbg_blank
    mov  cx, dbg_blank_len
    call console_print_cx_dx
%endif
    call startup_show_usage
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE  ; no program means no clean run
    jmp  .cli_finished
.name_present:
    call cmd_source_name
%ifdef TRACE_STAGES
    mov  dx, dbg_name
    mov  cx, dbg_name_len
    call console_print_cx_dx
    mov  si, FNAME_BASE
    xor  cx, cx
.measure_name:
    cmp  byte [si], CH_NULL
    je   .name_ready
    inc  si
    inc  cx
    jmp  .measure_name
.name_ready:
    mov  dx, FNAME_BASE
    call console_print_cx_dx
%endif
    call dos_file_open
    jc   .open_refused
    call dos_file_read
    jc   .read_refused
    call dos_file_close
%ifdef TRACE_STAGES
    mov  dx, dbg_src_len
    mov  cx, dbg_src_len_len
    call console_print_cx_dx
    mov  dx, [g_src_len]
    call console_print_dec
%endif
    call parser_compile
%ifdef TRACE_STAGES
    mov  dx, dbg_code_len
    mov  cx, dbg_code_len_len
    call console_print_cx_dx
    mov  dx, [g_code_len]
    call console_print_dec
%endif
    call runtime_run
%ifdef TRACE_STAGES
    mov  dx, dbg_ran
    mov  cx, dbg_ran_len
    call console_print_cx_dx
%endif
    jmp  .cli_finished
.open_refused:
    mov  [g_dos_err], ax             ; no handle exists yet, so nothing to close
    jmp  err_fatal_source_unread
.read_refused:
    call dos_file_close
    test dx, dx
    jnz  err_fatal_source_overflow
    mov  [g_dos_err], ax
    jmp  err_fatal_source_read
.cli_finished:
    pop  bp
    ret

%ifdef TRACE_STAGES
; Development build markers, enabled with nasm -D TRACE_STAGES.
dbg_enter:          db 'stage: cli_run entered'
dbg_enter_len       equ $ - dbg_enter
dbg_blank:          db 'stage: command tail is blank'
dbg_blank_len       equ $ - dbg_blank
dbg_name:           db 'stage: name = '
dbg_name_len        equ $ - dbg_name
dbg_src_len:        db 'source bytes='
dbg_src_len_len     equ $ - dbg_src_len
dbg_code_len:       db 'stream cells='
dbg_code_len_len    equ $ - dbg_code_len
dbg_ran:            db 'stream executed'
dbg_ran_len         equ $ - dbg_ran
%endif

; startup_image_end -- first byte the image does not occupy, which the start-up
; check compares against SOURCE_BASE.
startup_image_end:

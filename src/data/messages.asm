; Operator-visible text.
;
; Messages are stored as plain byte runs with an explicit length because the
; project writes them with DOS function 40h. Function 09h would need a '$'
; terminator and would bypass any redirection made from the command line.

section .data align=1

; ---- Start-up and shutdown banners -----------------------------------------
msg_startup_head:   db 'TinyPrint16 -- direct-threaded Python interpreter'
msg_startup_head_len equ $ - msg_startup_head

msg_need_file:      db 'TinyPrint16 needs a source file.'
msg_need_file_len   equ $ - msg_need_file

msg_usage:          db 'usage: tinyprint16.com <file.py>'
msg_usage_len       equ $ - msg_usage

; ---- Fixed fragments of an error report ------------------------------------
msg_err_prefix:     db 'TinyPrint16: error '
msg_err_prefix_len  equ $ - msg_err_prefix

msg_at_prefix:      db ' at line '
msg_at_prefix_len   equ $ - msg_at_prefix

msg_col_prefix:     db ', column '
msg_col_prefix_len  equ $ - msg_col_prefix

msg_dos_prefix:     db 'dos error '
msg_dos_prefix_len  equ $ - msg_dos_prefix

; ---- One banner per error code ---------------------------------------------
msg_e01:            db 'missing source file name'
msg_e01_len         equ $ - msg_e01
msg_e02:            db 'cannot open source file'
msg_e02_len         equ $ - msg_e02
msg_e03:            db 'cannot read source file'
msg_e03_len         equ $ - msg_e03
msg_e04:            db 'source file is larger than the source buffer'
msg_e04_len         equ $ - msg_e04
msg_e05:            db 'string literals are larger than the string pool'
msg_e05_len         equ $ - msg_e05
msg_e06:            db 'program is larger than the threaded-code buffer'
msg_e06_len         equ $ - msg_e06
msg_e07:            db 'unexpected character'
msg_e07_len         equ $ - msg_e07
msg_e08:            db 'expected the print keyword'
msg_e08_len         equ $ - msg_e08
msg_e09:            db 'missing ( after print'
msg_e09_len         equ $ - msg_e09
msg_e10:            db 'print needs a string literal'
msg_e10_len         equ $ - msg_e10
msg_e11:            db 'missing ) after the string'
msg_e11_len         equ $ - msg_e11
msg_e12:            db 'unexpected text after the closing parenthesis'
msg_e12_len         equ $ - msg_e12
msg_e13:            db 'unsupported escape sequence, only \" and \\ are allowed'
msg_e13_len         equ $ - msg_e13
msg_e14:            db 'cannot write to standard output'
msg_e14_len         equ $ - msg_e14
msg_e15:            db 'string literal is not closed'
msg_e15_len         equ $ - msg_e15

; ---- Diagnostics that do not depend on the source text ---------------------
msg_arena_overlap:  db 'TinyPrint16: arenas overlap the code, rebuild needed'
msg_arena_overlap_len equ $ - msg_arena_overlap

msg_name_too_long:  db 'TinyPrint16: the file name is longer than the arena'
msg_name_too_long_len equ $ - msg_name_too_long

msg_too_many_args:  db 'TinyPrint16: too many names, one source file is enough'
msg_too_many_args_len equ $ - msg_too_many_args

msg_stack_imbalance: db 'TinyPrint16: the call frame did not unwind'
msg_stack_imbalance_len equ $ - msg_stack_imbalance

msg_internal:       db 'TinyPrint16: internal error, unknown error code'
msg_internal_len    equ $ - msg_internal

; ---- Keyword text used by the front end ------------------------------------
keyword_print:      db 'print', CH_NULL

; ---- Banner lookup ---------------------------------------------------------
; Both tables are indexed by the error code carried in g_err_code, so the
; banner of ERR_n is entry n. Entry 0 is unused and stands for "no error".
msg_table:          dw 0
                    dw msg_e01
                    dw msg_e02
                    dw msg_e03
                    dw msg_e04
                    dw msg_e05
                    dw msg_e06
                    dw msg_e07
                    dw msg_e08
                    dw msg_e09
                    dw msg_e10
                    dw msg_e11
                    dw msg_e12
                    dw msg_e13
                    dw msg_e14
                    dw msg_e15

msg_len_table:      dw 0
                    dw msg_e01_len
                    dw msg_e02_len
                    dw msg_e03_len
                    dw msg_e04_len
                    dw msg_e05_len
                    dw msg_e06_len
                    dw msg_e07_len
                    dw msg_e08_len
                    dw msg_e09_len
                    dw msg_e10_len
                    dw msg_e11_len
                    dw msg_e12_len
                    dw msg_e13_len
                    dw msg_e14_len
                    dw msg_e15_len

MSG_TABLE_ENTRIES   equ 16

; Mutable runtime state.
;
; A .COM program has no link-time relocation, so the interpreter keeps its
; state in a handful of named words instead of passing structures around.
; The comment above each group names the only modules allowed to touch it.

section .data align=1

; ---- Source text (io/dos_file.asm writes it, frontend/lexer.asm reads it) --
        g_src_len       dw 0            ; bytes of text stored in SOURCE_BASE
        g_src_pos       dw 0            ; lexer cursor, offset into SOURCE_BASE

; ---- Position reporting (frontend/lexer.asm) -------------------------------
        g_line          dw 1            ; line of the character at g_src_pos
        g_col           dw 1            ; column of that character, one based
        g_tok_line      dw 1            ; position where the last token began
        g_tok_col       dw 1

; ---- Current token (frontend/lexer.asm -> frontend/parser.asm) -------------
        g_tok           db TOK_EOF      ; one of the TOK_* kinds
        g_str_off       dw 0            ; TOK_STRING: address of its first byte
        g_str_len       dw 0            ; TOK_STRING: bytes stored in the pool
        g_pool_ptr      dw STRING_BASE  ; next free byte of the string pool

; ---- Compiled program (frontend/compiler.asm -> runtime/) ------------------
        g_code_len      dw 0            ; cells written into CODE_BASE

; ---- File loading (io/dos_file.asm) ----------------------------------------
        g_file_handle   dw 0

; ---- Diagnostics (errors/error_handler.asm) --------------------------------
        g_err_code      db ERR_NO_SOURCE ; selects a banner from msg_table
        g_exit_code     db EXIT_CLEAN    ; value returned to DOS
        g_dos_err       dw 0            ; AX of the DOS call that failed

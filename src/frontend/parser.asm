; Syntax analysis of the supported subset.
;
; The grammar has one production, so the parser is a straight check of the
; token kinds that the lexer leaves in g_tok. Everything it accepts it hands to
; the compiler immediately; everything it rejects it reports at once.

section .text

; parser_compile -- turns the source buffer into an execution stream.
parser_compile:
    push bp
    lea  bp, [bp + 2]
    call lexer_reset
    call parser_program
    call compiler_finish
    pop  bp
    ret

; parser_program -- parses statements until the source is used up.
parser_program:
    call parser_skip_blank_lines
.next_statement:
    call lexer_next
    cmp  byte [g_tok], TOK_EOF
    je   .source_consumed
    call parser_statement
    call parser_end_of_statement
    jmp  .next_statement
.source_consumed:
    ret

; parser_skip_blank_lines -- consumes line breaks and the blanks around them.
parser_skip_blank_lines:
    call lexer_skip_blanks
.keep_crossing:
    call lexer_cross_line
    test ax, ax
    jnz  .keep_crossing
    ret

; parser_end_of_statement -- rejects anything that follows a statement on the
; same line, because the grammar has no way to combine two statements there.
parser_end_of_statement:
    call lexer_skip_blanks
    call lexer_cross_line
    test ax, ax
    jnz  .statement_finished
    call lexer_peek
    test al, al
    jz   .statement_finished           ; the source ends with the statement
    jmp  err_fatal_trailing_token
.statement_finished:
    ret

; parser_statement -- validates "print ( literal )" and emits its record.
; An identifier that is not the keyword is rejected by the lexer already, so
; only the token kinds of the production are checked here. A line that ends
; before the token arrives is reported as the missing token rather than as an
; unexpected carriage return.
parser_statement:
    cmp  byte [g_tok], TOK_PRINT
    jne  err_fatal_bad_keyword
    call lexer_at_line_end
    jc   err_fatal_missing_lparen
    call lexer_next
    cmp  byte [g_tok], TOK_LPAREN
    jne  err_fatal_missing_lparen
    call lexer_at_line_end
    jc   err_fatal_missing_string
    call lexer_next
    cmp  byte [g_tok], TOK_STRING
    jne  err_fatal_missing_string
    call compiler_emit_print
    call lexer_at_line_end
    jc   err_fatal_missing_rparen
    call lexer_next
    cmp  byte [g_tok], TOK_RPAREN
    jne  err_fatal_missing_rparen
    ret

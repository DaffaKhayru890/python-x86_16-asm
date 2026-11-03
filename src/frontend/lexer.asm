; Lexical analysis of the supported subset.
;
; The lexer never rewinds: it consumes the source buffer once and leaves the
; description of the token it read in the words declared in data/buffers.asm.

section .text

; lexer_reset -- places the cursor on the first character of the source.
; Clobbers: AX.
lexer_reset:
    mov  word [g_src_pos], 0
    mov  word [g_line], 1
    mov  word [g_col], 1
    ret

; lexer_peek -- the character at the cursor, or zero at the end of the source.
; g_src_pos counts from the start of the arena, so it is the displacement that
; is added to SOURCE_BASE rather than an address of its own.
; Clobbers: AX, BX.
lexer_peek:
    mov  bx, [g_src_pos]
    cmp  bx, [g_src_len]
    jae  .beyond_source
    mov  al, [SOURCE_BASE + bx]
    xor  ah, ah
    ret
.beyond_source:
    xor  ax, ax
    ret

; lexer_peek_char -- the same character in DX, which keeps AX free for a caller
; that has to test the result with the sign of a byte.
; Clobbers: BX, DX.
lexer_peek_char:
    mov  bx, [g_src_pos]
    cmp  bx, [g_src_len]
    jae  .beyond_source
    xor  dx, dx
    mov  dl, [SOURCE_BASE + bx]
    ret
.beyond_source:
    xor  dx, dx
    ret

; lexer_step -- consumes the character at the cursor and updates the position.
; A line feed advances the line counter and resets the column.
; Clobbers: BX.
lexer_step:
    push ax
    mov  bx, [g_src_pos]
    cmp  bx, [g_src_len]
    jae  .nothing_to_consume
    mov  al, [SOURCE_BASE + bx]
    cmp  al, CH_LF
    je   .line_terminates
    inc  word [g_col]
    jmp  .move_cursor
.line_terminates:
    inc  word [g_line]
    mov  word [g_col], 1
.move_cursor:
    inc  word [g_src_pos]
.nothing_to_consume:
    pop  ax
    ret

; lexer_is_alpha -- CF set when AL starts or continues an identifier.
; Clobbers: AX.
lexer_is_alpha:
    cmp  al, CH_UPPER_A
    jb   .test_lower_case
    cmp  al, CH_UPPER_Z
    jbe  .is_alpha
.test_lower_case:
    cmp  al, CH_LOWER_A
    jb   .not_alpha
    cmp  al, CH_LOWER_Z
    ja   .not_alpha
.is_alpha:
    stc
    ret
.not_alpha:
    clc
    ret

; lexer_skip_blanks -- consumes spaces and tabs, never a line break.
; Clobbers: AX, BX.
lexer_skip_blanks:
    call lexer_peek
    cmp  al, CH_SPACE
    je   .consume
    cmp  al, CH_TAB
    jne  .ready
.consume:
    call lexer_step
    jmp  lexer_skip_blanks
.ready:
    ret

; lexer_cross_line -- consumes one or more line breaks and the blanks that
; follow them. Returns AX = 1 when a line was crossed, AX = 0 otherwise.
; Clobbers: AX, BX.
lexer_cross_line:
    call lexer_peek
    cmp  al, CH_CR
    je   .cross
    cmp  al, CH_LF
    jne  .same_line
.cross:
    call lexer_step
    call lexer_skip_blanks
    call lexer_peek
    cmp  al, CH_CR
    je   .cross
    cmp  al, CH_LF
    je   .cross
    mov  ax, 1
    ret
.same_line:
    xor  ax, ax
    ret

; lexer_at_line_end -- CF set when only blanks separate the cursor from the end
; of the line or of the source. The cursor does not move, so a caller that finds
; the test clear can still read the token it was expecting.
; Clobbers: AX, BX.
lexer_at_line_end:
    mov  bx, [g_src_pos]
    mov  al, [SOURCE_BASE + bx]
    inc  bx
    xor  ah, ah
    cmp  bx, [g_src_len]
    ja   .source_ends_here          ; the walk fell off the end of the text
.walk:
    cmp  al, CH_SPACE
    je   .take_next
    cmp  al, CH_TAB
    je   .take_next
    cmp  al, CH_CR
    je   .line_ends_here
    cmp  al, CH_LF
    je   .line_ends_here
    clc
    ret
.take_next:
    cmp  bx, [g_src_len]
    jae  .source_ends_here
    mov  al, [SOURCE_BASE + bx]
    inc  bx
    jmp  .walk
.line_ends_here:
.source_ends_here:
    stc
    ret

; lexer_next -- reads the token that starts at the cursor.
; Sets g_tok, g_tok_line and g_tok_col, and for a string literal the pair
; g_str_off and g_str_len. For an unusable character the offending byte is
; handed to errors/ in DX.
; Clobbers: AX, BX, CX, DX. Preserves: SI.
lexer_next:
    call lexer_skip_blanks
    mov  ax, [g_line]
    mov  [g_tok_line], ax
    mov  ax, [g_col]
    mov  [g_tok_col], ax
    call lexer_peek
    test al, al
    jz   .source_is_exhausted
    cmp  al, CH_LPAREN
    je   .bracket
    cmp  al, CH_RPAREN
    je   .bracket
    cmp  al, CH_QUOTE
    je   .literal
    call lexer_is_alpha
    jc   .identifier
.unusable:
    mov  dx, ax
    jmp  err_fatal_bad_character
.identifier:
    call lexer_read_identifier
    call lexer_is_keyword_print
    jc   .keyword_recognised
    jmp  err_fatal_bad_keyword
.keyword_recognised:
    mov  byte [g_tok], TOK_PRINT
    ret
.bracket:
    call lexer_step
    cmp  al, CH_LPAREN
    jne  .closing_bracket
    mov  byte [g_tok], TOK_LPAREN
    ret
.closing_bracket:
    mov  byte [g_tok], TOK_RPAREN
    ret
.literal:
    call lexer_read_literal
    mov  byte [g_tok], TOK_STRING
    ret
.source_is_exhausted:
    mov  byte [g_tok], TOK_EOF
    ret

; lexer_read_identifier -- copies the identifier at the cursor to IDENT_BASE
; and folds upper-case letters into lower-case ones. The copy stops at
; IDENT_SIZE - 1 so that the terminator always fits.
; Clobbers: AX, BX, CX, DI.
lexer_read_identifier:
    mov  di, IDENT_BASE
    xor  cx, cx
.next_character:
    cmp  cx, IDENT_SIZE - 1
    jae  .terminate_copy
    call lexer_peek
    call lexer_is_alpha
    jnc  .terminate_copy
    cmp  al, CH_UPPER_A
    jb   .store_character
    cmp  al, CH_UPPER_Z
    ja   .store_character
    add  al, CH_LOWER_A - CH_UPPER_A
.store_character:
    mov  [di], al
    inc  di
    inc  cx
    call lexer_step
    jmp  .next_character
.terminate_copy:
    mov  byte [di], CH_NULL
    ret

; lexer_is_keyword_print -- CF set when IDENT_BASE holds exactly "print".
; Clobbers: AL, BX, DI.
lexer_is_keyword_print:
    mov  bx, IDENT_BASE
    mov  di, keyword_print
.next_character:
    mov  al, [bx]
    cmp  al, [di]
    jne  .differs_from_keyword
    test al, al
    jz   .keyword_matched
    inc  bx
    inc  di
    jmp  .next_character
.keyword_matched:
    stc
    ret
.differs_from_keyword:
    clc
    ret

; lexer_read_literal -- decodes the quoted literal at the cursor into the pool.
; Only \" and \\ are honoured. Sets g_str_off and g_str_len. An empty literal
; stores nothing and yields a length of zero. The caller has already confirmed
; that the cursor sits on the opening quote, which the lexer itself never does.
; Clobbers: AX, BX, CX, DX. Preserves: SI, DI.
lexer_read_literal:
    mov  cx, [g_pool_ptr]              ; CX survives peek, step and store
    call lexer_step                    ; step over the opening quote
.next_character:
    call lexer_peek
    test al, al
    jz   err_fatal_unterminated_string
    cmp  al, CH_QUOTE
    je   .literal_closed
    cmp  al, CH_CR
    je   err_fatal_unterminated_string
    cmp  al, CH_LF
    je   err_fatal_unterminated_string
    cmp  al, CH_BACKSLASH
    je   .escape_sequence
    mov  dx, ax
    call memory_store_byte
    jc   err_fatal_string_overflow
    call lexer_step
    jmp  .next_character
.escape_sequence:
    call lexer_step                    ; consume the backslash itself
    call lexer_peek
    cmp  al, CH_QUOTE
    je   .store_escaped_character
    cmp  al, CH_BACKSLASH
    jne  err_fatal_bad_escape
.store_escaped_character:
    mov  dx, ax
    call memory_store_byte
    jc   err_fatal_string_overflow
    call lexer_step
    jmp  .next_character
.literal_closed:
    call lexer_step                    ; consume the closing quote
    mov  ax, [g_pool_ptr]
    sub  ax, cx
    mov  [g_str_len], ax               ; AX = bytes of decoded text
    mov  [g_str_off], cx               ; CX = where they start
    ret

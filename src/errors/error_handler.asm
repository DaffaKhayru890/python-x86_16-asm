; Error reporting.
;
; Every module hands a failure over by jumping to one of the entry points
; below; none of them returns. The entry point records which banner belongs to
; the failure and which code DOS should receive. The shared reporter then
; prints what is known: the message, the position in the source, the offending
; line, and the DOS error code when a DOS call produced the failure.

section .text

; ---- Entry points used by the file layer -----------------------------------
; The empty command tail is not reported here: main.asm prints the usage lines,
; which say more than a banner would, and leaves ERR_NO_SOURCE as the default
; value of g_err_code for any report that never got a code of its own.
err_fatal_source_unread:
    mov  byte [g_err_code], ERR_SOURCE_UNREAD
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
    jmp  err_report_and_exit

err_fatal_source_read:
    mov  byte [g_err_code], ERR_SOURCE_READ
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
    jmp  err_report_and_exit

err_fatal_source_overflow:
    mov  byte [g_err_code], ERR_SOURCE_OVERFLOW
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
    jmp  err_report_and_exit

; ---- Entry points used by the front end ------------------------------------
err_fatal_bad_character:
    mov  byte [g_err_code], ERR_BAD_CHAR
    mov  byte [g_exit_code], EXIT_BAD_CHARACTER
    jmp  err_report_and_exit

err_fatal_bad_keyword:
    mov  byte [g_err_code], ERR_BAD_KEYWORD
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit

err_fatal_missing_lparen:
    mov  byte [g_err_code], ERR_MISSING_LPAREN
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit

err_fatal_missing_string:
    mov  byte [g_err_code], ERR_MISSING_STRING
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit

err_fatal_missing_rparen:
    mov  byte [g_err_code], ERR_MISSING_RPAREN
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit

err_fatal_unterminated_string:
    mov  byte [g_err_code], ERR_UNTERMINATED
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit

err_fatal_trailing_token:
    mov  byte [g_err_code], ERR_TRAILING_TOKEN
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit

err_fatal_bad_escape:
    mov  byte [g_err_code], ERR_BAD_ESCAPE
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit

; ---- Entry points used when an arena or the console fails ------------------
err_fatal_string_overflow:
    mov  byte [g_err_code], ERR_STRING_OVERFLOW
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
    jmp  err_report_and_exit

err_fatal_thread_overflow:
    mov  byte [g_err_code], ERR_THREAD_OVERFLOW
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
    jmp  err_report_and_exit

err_fatal_output_refused:
    mov  [g_dos_err], ax
    mov  byte [g_err_code], ERR_OUTPUT_REFUSED
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
    jmp  err_report_and_exit

; err_fatal_exit -- a diagnostic has already been printed by its own module.
err_fatal_exit:
    mov  byte [g_exit_code], EXIT_SYSTEM_FAILURE
    jmp  err_fatal_leave

; err_fatal_leave -- ends a run that reported a failure. BP is put back where
; prog_start left it because leaving through DOS unwinds no frame at all; the
; unwind check in core/shutdown.asm stays meaningful for the clean path.
err_fatal_leave:
    mov  bp, STACK_TOP
    jmp  shutdown_exit

; err_fatal_internal -- reports a defect of the interpreter itself.
err_fatal_internal:
    push ax
    push bx
    push cx
    push dx
    mov  dx, msg_internal
    mov  cx, msg_internal_len
    call console_print_cx_dx
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    jmp  err_fatal_exit

; ---- The shared reporter ---------------------------------------------------
; err_report_and_exit -- prints what is known about the failure, then exits.
err_report_and_exit:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    call err_report_banner
    call err_report_source_position
    call err_report_dos_error
    pop  bp
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    jmp  err_fatal_leave

; err_report_banner -- "TinyPrint16: error <banner>", one line.
err_report_banner:
    push ax
    push bx
    push cx
    push dx
    mov  dx, msg_err_prefix
    mov  cx, msg_err_prefix_len
    call console_write_cx
    mov  al, [g_err_code]
    cmp  al, MSG_TABLE_ENTRIES - 1
    jbe  .code_inside_table
    mov  al, MSG_TABLE_ENTRIES - 1           ; stay inside the banner table
.code_inside_table:
    xor  ah, ah
    add  ax, ax                              ; the tables hold words
    mov  bx, ax
    mov  si, msg_table
    add  si, bx
    mov  dx, [si]                            ; offset of the banner text
    mov  di, msg_len_table
    add  di, bx
    mov  cx, [di]                            ; length of the banner text
    call console_print_cx_dx
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; err_report_source_position -- line, column, then the offending source line.
; Only failures that point into the text are worth a position.
err_report_source_position:
    push ax
    push bx
    push cx
    push dx
    call err_is_source_error
    jc   .nothing_to_report
    mov  dx, msg_at_prefix
    mov  cx, msg_at_prefix_len
    call console_write_cx
    mov  dx, [g_tok_line]
    call console_print_dec
    mov  dx, msg_col_prefix
    mov  cx, msg_col_prefix_len
    call console_write_cx
    mov  dx, [g_tok_col]
    call console_print_dec
    call err_report_excerpt
.nothing_to_report:
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; err_is_source_error -- CF clear when the failure points into the source text.
err_is_source_error:
    mov  ax, 0
    mov  al, [g_exit_code]
    cmp  ax, EXIT_BAD_SYNTAX
    ja   .not_in_source
    test ax, ax
    jz   .not_in_source
    clc
    ret
.not_in_source:
    stc
    ret

; err_report_excerpt -- reprints the line that holds the cursor and marks the
; column of the token underneath it. The line is compacted into the head of the
; source buffer, which is allowed because the program ends after the report.
; Spaces and tabs count towards the column, so the mark stays beneath the
; character the lexer was looking at.
; Clobbers: AX, BX, CX, DX, SI, DI.
err_report_excerpt:
    push bp
    lea  bp, [bp + 2]
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov  si, [g_src_pos]                     ; SI = cursor, the end of the line
    mov  di, si
.walk_back_to_line_start:
    test di, di
    jz   .line_start_found
    mov  bx, di
    dec  bx
    mov  al, [SOURCE_BASE + bx]
    cmp  al, CH_LF
    je   .line_start_found
    mov  di, bx
    jmp  .walk_back_to_line_start
.line_start_found:
    mov  bx, di                              ; BX reads the line
    xor  di, di                              ; DI writes it at the buffer head
.copy_line_character:
    cmp  bx, si
    jae  .line_copied
    mov  al, [SOURCE_BASE + bx]
    cmp  al, CH_CR                           ; DOS files carry redundant CRs
    je   .skip_carriage_return
    mov  [SOURCE_BASE + di], al
    inc  di
.skip_carriage_return:
    inc  bx
    jmp  .copy_line_character
.line_copied:
    mov  cx, di                              ; CX = bytes of the excerpt
    mov  dx, SOURCE_BASE
    call console_print_cx_dx                 ; keeps the registers used below
    mov  di, SOURCE_BASE
    add  di, cx
    inc  di                                  ; one byte of separation
    mov  dx, di                              ; DX = start of the mark line
    mov  ax, [g_tok_col]
    dec  ax                                  ; AX = characters before the mark
    cmp  ax, cx
    jbe  .mark_column_inside_line
    mov  ax, cx                              ; never point past the excerpt
    dec  ax
.mark_column_inside_line:
    mov  bx, ax
    mov  al, CH_SPACE
.fill_mark_blank:
    test bx, bx
    jz   .mark_blanks_filled
    mov  [di], al
    inc  di
    dec  bx
    jmp  .fill_mark_blank
.mark_blanks_filled:
    mov  byte [di], CH_CARET
    inc  di
    mov  cx, di
    sub  cx, dx                              ; CX = bytes of the mark line
    call console_print_cx_dx
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret

; err_report_dos_error -- the code returned by the DOS call, when there was one.
err_report_dos_error:
    push ax
    push bx
    push cx
    push dx
    mov  ax, [g_dos_err]
    test ax, ax
    jz   .no_dos_code
    mov  dx, msg_dos_prefix
    mov  cx, msg_dos_prefix_len
    call console_write_cx
    mov  ax, [g_dos_err]
    call console_print_hex4
    call console_print_crlf
.no_dos_code:
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

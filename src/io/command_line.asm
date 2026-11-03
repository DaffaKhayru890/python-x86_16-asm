; Parsing of the DOS command tail.
;
; The tail at PSP_CMD_TEXT is a counted, space-prefixed, CR-terminated run of
; bytes, so it has to be split into names before any file is opened. A name may
; be wrapped in double quotes when its path contains spaces.

section .text

; cmd_split -- isolates the first name of the command tail.
; Returns: BX = first character of the name (DI = BX when the tail is empty),
;          DI = just past the name, quotes excluded,
;          CF set when a second name follows the first one.
; Clobbers: AX, BX, CX, SI, DI. BP is left alone because it carries the frame
; counter of the caller.
cmd_split:
    mov  si, PSP_CMD_TEXT
    xor  ax, ax
    mov  al, [PSP_CMD_LEN]              ; byte count taken from the PSP
    mov  cx, ax
    add  cx, si                         ; CX = end of the tail
.skip_leading_blank:
    cmp  si, cx
    jae  .tail_holds_nothing
    mov  al, [si]
    cmp  al, CH_SPACE
    je   .step_over
    cmp  al, CH_TAB
    jne  .name_starts_here
.step_over:
    inc  si
    jmp  .skip_leading_blank
.name_starts_here:
    cmp  al, CH_QUOTE
    je   .quoted_name
    mov  bx, si
    inc  si
.scan_plain_name:
    cmp  si, cx
    jae  .plain_name_ends
    mov  al, [si]
    cmp  al, CH_SPACE
    je   .plain_name_ends
    cmp  al, CH_TAB
    je   .plain_name_ends
    cmp  al, CH_CR
    je   .plain_name_ends
    inc  si
    jmp  .scan_plain_name
.plain_name_ends:
    mov  di, si
    mov  si, cx                         ; trim the blanks that follow the name
.trim_trailing_blank:
    cmp  si, di
    jbe  .plain_only_name
    mov  al, [si - 1]
    cmp  al, CH_SPACE
    je   .drop_trailing
    cmp  al, CH_TAB
    je   .drop_trailing
    cmp  al, CH_CR
    je   .drop_trailing
    jmp  .plain_second_name
.drop_trailing:
    dec  si
    jmp  .trim_trailing_blank
.plain_second_name:
    stc
    ret
.plain_only_name:
    clc
    ret
.quoted_name:
    inc  si                             ; the opening quote is not part of it
    mov  bx, si
.scan_quoted_name:
    cmp  si, cx
    jae  .quoted_name_ends
    cmp  byte [si], CH_QUOTE
    je   .quoted_name_ends
    inc  si
    jmp  .scan_quoted_name
.quoted_name_ends:
    mov  di, si                         ; the closing quote is not part of it
    cmp  si, cx
    jae  .quoted_tail_is_empty
    inc  si                             ; step over the closing quote
.search_second_name:
    cmp  si, cx
    jae  .quoted_tail_is_empty
    mov  al, [si]
    cmp  al, CH_SPACE
    je   .step_over_second
    cmp  al, CH_TAB
    je   .step_over_second
    cmp  al, CH_CR
    je   .step_over_second
    stc                                 ; a second name really is present
    ret
.step_over_second:
    inc  si
    jmp  .search_second_name
.quoted_tail_is_empty:
    clc
    ret
.tail_holds_nothing:
    mov  bx, si
    mov  di, si
    clc
    ret

; cmd_is_blank_line -- reports whether the command tail carries a name.
; Returns: ZF clear when a name is present.
; Clobbers: AX, BX, CX, SI, DI.
cmd_is_blank_line:
    call cmd_split
    mov  ax, di
    sub  ax, bx
    ret

; cmd_source_name -- copies the first tail name into FNAME_BASE as an ASCIZ path.
; Ends the run with a diagnostic when the tail holds a second name or when the
; first name does not fit the arena.
; Clobbers: AX, CX, DX, SI, DI.
cmd_source_name:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    call cmd_split
    jc   .second_name
    mov  ax, di
    sub  ax, bx                          ; AX = length of the name
    cmp  ax, FNAME_SIZE - 1
    ja   .name_too_long
    mov  cx, ax
    mov  si, bx
    mov  di, FNAME_BASE
    rep movsb                            ; ES equals DS, set at start-up
    mov  byte [di], CH_NULL
    jmp  .name_taken
.name_too_long:
    mov  dx, msg_name_too_long
    mov  cx, msg_name_too_long_len
    call console_print_cx_dx
    jmp  err_fatal_exit
.second_name:
    mov  dx, msg_too_many_args
    mov  cx, msg_too_many_args_len
    call console_print_cx_dx
    jmp  err_fatal_exit
.name_taken:
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

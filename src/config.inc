; TinyPrint16 -- central configuration.
;
; Every DOS service number, arena address and language limit used by the
; project is defined here, so no module has to carry a magic number.

%ifndef TINYPRINT16_CONFIG_INC
%define TINYPRINT16_CONFIG_INC

; ---------------------------------------------------------------------------
; Executable layout
; ---------------------------------------------------------------------------
; A .COM image is loaded at CS:0100h, directly above the 256-byte program
; segment prefix. ORG 100h therefore makes every assembled offset equal to
; its runtime offset, which is what allows the compiler to store 16-bit near
; offsets as executable tokens.
        COM_ORIGIN      equ 100h

; ---------------------------------------------------------------------------
; Working arenas
; ---------------------------------------------------------------------------
; NASM cannot emit a BSS for "-f bin", so scratch memory is addressed through
; fixed offsets near the top of the segment. The assembled image ends far
; below 2000h; the LAYOUT checks in main.asm refuse the build if an arena and
; the stack no longer fit below 0FF00h.
        SOURCE_BASE     equ 2000h     ; source text read from the .py file
        SOURCE_SIZE     equ 1000h     ; 4096 bytes
        STRING_BASE     equ 3000h     ; decoded string literals
        STRING_SIZE     equ 0800h     ; 2048 bytes
        CODE_BASE       equ 4000h     ; threaded execution stream
        CODE_SIZE       equ 0800h     ; 2048 bytes = 1024 cells
        IDENT_BASE      equ 4800h     ; current identifier token
        IDENT_SIZE      equ 0020h     ; 32 bytes, terminator included
        FNAME_BASE      equ 4880h     ; ASCIZ path taken from the command tail
        FNAME_SIZE      equ 0080h     ; 128 bytes
        SCRATCH_BASE    equ 4900h     ; formatting and probing scratch, 32 bytes
        STACK_BASE      equ 5000h     ; the lowest address the stack may reach
        STACK_SIZE      equ 1000h     ; 4096 bytes, about 100 nested calls
        STACK_TOP       equ 6000h     ; SP at entry and the origin of the frames

; Scratch slots. Each owner gets its own range: the digit builders and the CRLF
; pair would otherwise overwrite one another mid-report.
        DECIMAL_SLOT    equ SCRATCH_BASE        ; up to five digits plus CRLF
        HEX4_SLOT       equ SCRATCH_BASE + 10h  ; four hexadecimal digits
        CH_CRLF_SLOT    equ SCRATCH_BASE + 20h  ; the two bytes filled at start-up
        READ_PROBE      equ SCRATCH_BASE + 22h  ; the byte past a full arena
        SCRATCH_SIZE    equ 0020h               ; total bytes held by the arena

; ---------------------------------------------------------------------------
; Language limits
; ---------------------------------------------------------------------------
        MAX_PROGRAM_CELLS   equ (CODE_SIZE / 2) - 1   ; one cell for HALT
        MAX_STRING_BYTES    equ STRING_SIZE - 1       ; terminator is reserved

; ---------------------------------------------------------------------------
; DOS services (INT 21h)
; ---------------------------------------------------------------------------
        INT_DOS         equ 21h
        DOS_OPEN        equ 3Dh     ; AL = mode, DS:DX = ASCIZ name
        DOS_CLOSE       equ 3Eh     ; BX = handle
        DOS_READ        equ 3Fh     ; BX = handle, CX = count, DS:DX = buffer
        DOS_WRITE       equ 40h     ; BX = handle, CX = count, DS:DX = buffer
        DOS_EXIT        equ 4Ch     ; AL = return code
        DOS_STDOUT      equ 0001h   ; handle 1, honouring a DOS redirection

        DOS_OPEN_READ   equ 00h     ; read-only access mode

        SOURCE_READ_CHUNK equ 200h  ; 512 bytes per DOS read
        HEX_ALPHA_OFFSET  equ 07h   ; moves a nibble past '9' into 'A'..'F'

; Command tail in the program segment prefix.
        PSP_CMD_LEN     equ 0080h   ; byte count of the tail
        PSP_CMD_TEXT    equ 0081h   ; first character of the tail

; ---------------------------------------------------------------------------
; Token kinds produced by frontend/lexer.asm
; ---------------------------------------------------------------------------
        TOK_EOF         equ 0       ; source exhausted
        TOK_PRINT       equ 1       ; the one keyword the grammar accepts
        TOK_LPAREN      equ 2
        TOK_RPAREN      equ 3
        TOK_STRING      equ 4       ; value in STRING_BASE, length in g_str_len

; The text of the only keyword lives in data/messages.asm, where the lexer can
; compare it one character at a time.

; ---------------------------------------------------------------------------
; Error codes reported through data/messages.asm. Codes 7 to 13 are syntax
; errors, so the source position and the marked token are printed with them.
; ---------------------------------------------------------------------------
        ERR_NO_SOURCE       equ 1   ; command tail carries no file name
        ERR_SOURCE_UNREAD   equ 2   ; DOS refused to open the file
        ERR_SOURCE_READ     equ 3   ; DOS refused to read from the handle
        ERR_SOURCE_OVERFLOW equ 4   ; source larger than SOURCE_SIZE
        ERR_STRING_OVERFLOW equ 5   ; literals larger than STRING_SIZE
        ERR_THREAD_OVERFLOW equ 6   ; program larger than CODE_SIZE
        ERR_BAD_CHAR        equ 7   ; character outside the grammar
        ERR_BAD_KEYWORD     equ 8   ; identifier that is not "print"
        ERR_MISSING_LPAREN  equ 9   ; no "(" after the keyword
        ERR_MISSING_STRING  equ 10  ; no string literal after "("
        ERR_MISSING_RPAREN  equ 11  ; no ")" after the string
        ERR_TRAILING_TOKEN  equ 12  ; something follows ")" on the same line
        ERR_BAD_ESCAPE      equ 13  ; an escape the lexer does not honour
        ERR_OUTPUT_REFUSED  equ 14  ; DOS refused to write the line
        ERR_UNTERMINATED    equ 15  ; the closing quote is missing

; Exit codes handed to DOS. EXIT_BAD_CHARACTER and EXIT_BAD_SYNTAX are also
; the length of the marker drawn under the offending token.
        EXIT_CLEAN             equ 0
        EXIT_BAD_CHARACTER     equ 1
        EXIT_BAD_SYNTAX        equ 2
        EXIT_SYSTEM_FAILURE    equ 3

; ---------------------------------------------------------------------------
; Character constants
; ---------------------------------------------------------------------------
        CH_NULL         equ 0
        CH_TAB          equ 09h
        CH_LF           equ 0Ah
        CH_CR           equ 0Dh
        CH_SPACE        equ 20h
        CH_QUOTE        equ 22h     ; the double quote
        CH_LPAREN       equ 28h
        CH_RPAREN       equ 29h
        CH_DIGIT_ZERO   equ 30h
        CH_DIGIT_NINE   equ 39h
        CH_BACKSLASH    equ 5Ch
        CH_CARET        equ 5Eh     ; marks the token in a syntax report
        CH_UPPER_A      equ 41h
        CH_UPPER_Z      equ 5Ah
        CH_LOWER_A      equ 61h
        CH_LOWER_Z      equ 7Ah

%endif

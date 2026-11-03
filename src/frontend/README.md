# `src/frontend` — text in, stream out

Three stages, three files, and none of them prints anything: a refusal is a jump
into [`../errors/`](../errors/README.md).

| File | Responsibility |
| --- | --- |
| [`lexer.asm`](lexer.asm) | read characters once, produce token kinds and positions |
| [`parser.asm`](parser.asm) | check the one production of the grammar |
| [`compiler.asm`](compiler.asm) | append the handler address and its operands to the stream |

## lexer.asm

The lexer never rewinds. It consumes `SOURCE_BASE` from `g_src_pos` forwards and
leaves what it found in the state words of
[`../data/buffers.asm`](../data/buffers.asm): `g_tok` for the kind, `g_tok_line`
and `g_tok_col` for where it began, `g_str_off`/`g_str_len` for a literal.

| Routine | Contract |
| --- | --- |
| `lexer_reset` | put the cursor on the first character, line and column at 1 |
| `lexer_peek` | the character at the cursor in `AL`, zero past the end |
| `lexer_peek_char` | the same character in `DX`, leaving `AX` free for the caller |
| `lexer_step` | consume one character, LF advances the line and resets the column |
| `lexer_is_alpha` | `CF` set for `A`-`Z` and `a`-`z` |
| `lexer_skip_blanks` | spaces and tabs, never a line break |
| `lexer_cross_line` | consume breaks and the blanks after them; `AX` = 1 if a line was crossed |
| `lexer_at_line_end` | `CF` set when only blanks separate the cursor from the line end |
| `lexer_next` | read the token at the cursor |
| `lexer_read_identifier` | copy it to `IDENT_BASE`, folded to lower case |
| `lexer_is_keyword_print` | `CF` set when `IDENT_BASE` holds exactly `print` |
| `lexer_read_literal` | decode the quoted text into the pool |

Two details that are easy to get wrong and are commented in the code:

* `g_src_pos` is an **index into the arena**, not an address, so every read is
  `[SOURCE_BASE + bx]`. Reading `[bx]` instead pointed the lexer at the PSP and
  made the first character of every file look like garbage.
* `lexer_peek` clobbers `BX` and `memory_store_byte` clobbers `DI`, so the two
  walkers hold their destination pointer in the register their callees leave
  alone: `DI` in `lexer_read_identifier`, `CX` in `lexer_read_literal`.

`lexer_next` decides the token from the first character: `(`/`)`, a quote, or a
letter. Anything else is `err_fatal_bad_character`; an identifier that is not
`print` is `err_fatal_bad_keyword`. `lexer_read_literal` honours only `\"` and
`\\` and stops at a line break, which is how an unclosed string is detected.

## parser.asm

The grammar is one production, so the parser is a sequence of token-kind checks
rather than a table:

```text
parser_compile : frame, lexer_reset, parser_program, compiler_finish
parser_program : blank lines, then statement, end of statement, repeat until TOK_EOF
parser_statement : TOK_PRINT TOK_LPAREN TOK_STRING -> compiler_emit_print -> TOK_RPAREN
parser_end_of_statement : only a line break or the end of the source may follow
```

Before each expectation, `parser_statement` asks `lexer_at_line_end`. A line that
stops early is reported as the token that is missing — `missing ) after the
string` for `print("x"` — instead of the confusing "unexpected character" a raw
`CR` would otherwise produce.

## compiler.asm

The compiler owns the shape of the stream and nothing else. One statement becomes

```text
  op_print   address of the literal   byte count
```

three cells appended through `memory_emit_cell`, and `compiler_finish` closes the
program with `op_halt` so the runtime never has to know a length. It does not
execute anything, and it does not know what its output means: only that the
handler whose address it writes expects those two operands. Each append is
followed by `jc err_fatal_thread_overflow`, which is what caps a program at 340
statements.

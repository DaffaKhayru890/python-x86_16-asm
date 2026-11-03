# `src/data` — state and text

| File | Responsibility |
| --- | --- |
| [`buffers.asm`](buffers.asm) | the mutable words the stages hand to one another |
| [`messages.asm`](messages.asm) | every byte of operator-visible text, and the keyword |

## buffers.asm

A `.COM` image has no relocations and no BSS section, so state lives in named
words in `.data` and modules communicate through them instead of passing
structures. Each group carries a comment naming the only modules allowed to touch
it, which is what keeps the shared state from turning into a mess:

| Group | Words | Owner |
| --- | --- | --- |
| source text | `g_src_len`, `g_src_pos` | written by `io/dos_file.asm`, read by `frontend/lexer.asm` |
| position | `g_line`, `g_col`, `g_tok_line`, `g_tok_col` | `frontend/lexer.asm` |
| current token | `g_tok`, `g_str_off`, `g_str_len`, `g_pool_ptr` | lexer to parser |
| compiled program | `g_code_len` | `frontend/compiler.asm` to `runtime/` |
| file loading | `g_file_handle` | `io/dos_file.asm` |
| diagnostics | `g_err_code`, `g_exit_code`, `g_dos_err` | `errors/error_handler.asm` |

Two of them are worth stating precisely, because both bitmaps and bugs come from
mixing them up:

* `g_src_pos` is an **index into `SOURCE_BASE`**, so a read is
  `[SOURCE_BASE + g_src_pos]`, never `[g_src_pos]`.
* `g_str_off` is the **address** of the literal (a pool cursor value, already
  based at `STRING_BASE`), which is what makes it usable as the operand cell of a
  PRINT record without further arithmetic.

`memory_reset` in [`../core/memory.asm`](../core/memory.asm) is the only place
that initialises these words for a run.

## messages.asm

Messages are plain byte runs each followed by `name_len equ $ - name`, because the
project writes them with DOS function `40h`, which wants a length rather than a
terminator. The `$` in that expression is the location counter, not the ASCII `$`:
the file relies on NASM computing `$ - label` at assembly time, which is also why
adding a message needs no manual count.

Four kinds of text live here:

* banners: `msg_startup_head`, `msg_need_file`, `msg_usage`;
* fixed fragments of a report: `msg_err_prefix`, `msg_at_prefix`,
  `msg_col_prefix`, `msg_dos_prefix`;
* one banner per error code, `msg_e01` … `msg_e15`, reachable through the two
  parallel tables at the bottom;
* module-specific diagnostics that are not tied to a source position, such as
  `msg_arena_overlap` and `msg_stack_imbalance`.

```asm
msg_table:      dw 0
                dw msg_e01
                ...
msg_len_table:  dw 0
                dw msg_e01_len
                ...
MSG_TABLE_ENTRIES equ 16
```

`g_err_code` indexes both tables, doubled because they hold words, and the
reporter clamps the index so a corrupt code cannot read outside them. Entry 0 is
the "no error" placeholder that keeps `ERR_n` and row `n` the same number.

`keyword_print` is the only piece of text in the file that is not output: the
lexer compares an identifier against it one character at a time, so the spelling
of the keyword exists in exactly one place.

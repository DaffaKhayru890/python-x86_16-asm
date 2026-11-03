# `src/errors` — one way to fail

| File | Responsibility |
| --- | --- |
| [`error_handler.asm`](error_handler.asm) | the entry points every module jumps to, and the reporter behind them |

## The shape of a failure

A module that cannot continue **jumps** to an entry point; it does not call one.
No entry point returns, which is why none of them needs a frame or a `ret`:

```asm
err_fatal_missing_rparen:
    mov  byte [g_err_code], ERR_MISSING_RPAREN
    mov  byte [g_exit_code], EXIT_BAD_SYNTAX
    jmp  err_report_and_exit
```

The entry point only records *which* banner and *which* exit code apply. The
shared reporter then prints everything that is known:

```text
TinyPrint16: error <banner>              from msg_table[g_err_code]
 at line N, column M                     from g_tok_line / g_tok_col
<the offending source line>              walked back to the previous LF
    ^                                    caret under the token
dos error XXXX                           when g_dos_err was filled by a DOS call
```

| Entry point | Banner | Exit |
| --- | --- | --- |
| `err_fatal_source_unread` | cannot open source file | 3 |
| `err_fatal_source_read` | cannot read source file | 3 |
| `err_fatal_source_overflow` | source file is larger than the source buffer | 3 |
| `err_fatal_bad_character` | unexpected character | 1 |
| `err_fatal_bad_keyword` | expected the print keyword | 2 |
| `err_fatal_missing_lparen` | missing ( after print | 2 |
| `err_fatal_missing_string` | print needs a string literal | 2 |
| `err_fatal_missing_rparen` | missing ) after the string | 2 |
| `err_fatal_unterminated_string` | string literal is not closed | 2 |
| `err_fatal_trailing_token` | unexpected text after the closing parenthesis | 2 |
| `err_fatal_bad_escape` | unsupported escape sequence, only `\"` and `\\` are allowed | 2 |
| `err_fatal_string_overflow` | string literals are larger than the string pool | 3 |
| `err_fatal_thread_overflow` | program is larger than the threaded-code buffer | 3 |
| `err_fatal_output_refused` | cannot write to standard output | 3 |
| `err_fatal_exit` | prints nothing, the module already did | 3 |
| `err_fatal_internal` | internal error, unknown error code | 3 |

`ERR_NO_SOURCE` and its banner have no entry point: a blank command tail is
answered with the two usage lines, which say more than a banner would. The code
stays as the initial value of `g_err_code`, so a report that somehow forgot to set
one still prints something.

## The reporter

`err_report_and_exit` saves `AX BX CX DX SI DI BP`, runs the three parts, restores
them and jumps to `err_fatal_leave`. The order matters: `g_dos_err` must already
hold the failing call's `AX`, which is why the file layer stores it before jumping.

`err_is_source_error` decides whether a position is worth printing, and it asks
the exit code rather than the error code: everything below `EXIT_BAD_SYNTAX` is a
fault of the text, everything above is a fault of DOS or of the interpreter, where
a line number would only mislead.

`err_report_excerpt` is the part that needed care. It walks back from `g_src_pos`
to the previous line feed, compacts that line into the head of `SOURCE_BASE`
(dropping the CR of a CRLF file, which is safe because the run ends with the
report), prints it, and then builds the caret line in the space the source line
just vacated. The column is clamped so the marker can never point past the text it
underlines. The whole walk uses `[SOURCE_BASE + bx]`: `g_src_pos` is an index, not
an address.

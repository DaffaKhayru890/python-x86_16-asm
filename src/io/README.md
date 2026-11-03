# `src/io` — the DOS boundary

| File | Responsibility |
| --- | --- |
| [`console.asm`](console.asm) | every byte the program prints, plus number formatting |
| [`dos_file.asm`](dos_file.asm) | open, read and close the source file |
| [`command_line.asm`](command_line.asm) | split the PSP command tail and copy the name to its arena |

## console.asm

Everything goes out through **DOS function `40h` on handle 1**. Function `09h`
would need a `$` terminator — and a `$` is an ordinary character inside a Python
string literal — and it would also ignore a redirection made on the command
line. Handle 1 is what makes `tinyprint16.com prog.py > out.txt` work.

| Routine | Contract |
| --- | --- |
| `console_write_cx` | write `CX` bytes at `DS:DX`; `CF` set with `AX` = DOS error |
| `console_print_crlf` | the two bytes pre-filled at `CH_CRLF_SLOT` |
| `console_print_cx_dx` | write the run and a line break, preserving every register |
| `console_print_dec` | `DX` as unsigned decimal, digits built backwards in `DECIMAL_SLOT` |
| `console_print_hex4` | `AX` as four hex digits in `HEX4_SLOT`, no line break |

`console_print_cx_dx` is the one everyone uses for messages because it is
register-transparent: the error reporter can call it between saving and restoring
its own registers without thinking. The two formatters are the reason
`SCRATCH_BASE` is split into separate slots in `config.inc` — sharing one range
made the hex digits overwrite the CRLF pair and turned every later line break into
two hex characters.

## dos_file.asm

`dos_file_open` issues `INT 21h` function `3Dh` in read mode and keeps the handle
in `g_file_handle`; the carry flag is handed straight back to `cli_run`.

`dos_file_read` pulls `SOURCE_READ_CHUNK` (512 bytes) at a time into `SOURCE_BASE`
and asks DOS for only what is left in the arena. When the arena is exactly full it
reads **one more byte into `READ_PROBE`** to tell "file is bigger than the arena"
apart from "file is exactly the arena size", which are different errors:

| Result | Meaning |
| --- | --- |
| `CF` clear, `AX` = bytes | the whole file is in `SOURCE_BASE` |
| `CF` set, `DX` = 1, `AX` = `SOURCE_SIZE` | the file does not fit |
| `CF` set, `DX` = 0, `AX` = DOS code | the read itself failed |

`dos_file_close` is called by `cli_run` on every path after a successful open,
including the failure paths.

## command_line.asm

The PSP gives the tail as a byte count at `PSP_CMD_LEN` and the text at
`PSP_CMD_TEXT`, space-prefixed and CR-terminated, so it has to be split before it
can be used.

| Routine | Contract |
| --- | --- |
| `cmd_split` | `BX` = first character of the first name, `DI` = just past it, `CF` set when a second name follows |
| `cmd_is_blank_line` | zero-length name means the tail carries nothing |
| `cmd_source_name` | copy the name into `FNAME_BASE` as an ASCIZ path |

`cmd_split` understands a name wrapped in double quotes, which is the only way a
DOS path with spaces can be passed at all. It never touches `BP`: that register
carries the caller's frame counter, and using it as a scratch pointer here was
another early silent failure. `cmd_source_name` refuses a name longer than
`FNAME_SIZE - 1` and refuses a second name — one source file per run is the whole
interface.

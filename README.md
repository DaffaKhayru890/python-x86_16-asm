# TinyPrint16

A tiny Python-like interpreter written entirely in x86 16-bit assembly. It reads
a `.py` file named on the DOS command line, compiles the statements it finds into
a **direct-threaded execution stream**, and runs that stream through an indirect
jump per instruction — no opcode switch, no decoding of source text at run time.

The language is deliberately one statement wide:

```python
print("Hello, World!")
print("This is TinyPrint16.")
print("Running on 16-bit x86!")
```

```text
Hello, World!
This is TinyPrint16.
Running on 16-bit x86!
```

Everything is one flat DOS `.COM` image, assembled from modular NASM sources and
runnable under DOSBox, DOSBox-X or real DOS on any 8086-compatible CPU.

---

## 1. Supported syntax

```text
program    = statement*
statement  = ws "print" ws "(" ws string ")" ws-line-end
string     = '"' character* '"'
```

* any number of `print` statements, one per line;
* spaces and tabs between tokens, blank lines anywhere between statements;
* an empty literal, `""`;
* ordinary printable ASCII inside a literal, `$` included;
* the escapes `\"` (a double quote) and `\\` (a backslash);
* `print` is recognised case-insensitively, so `Print("Hi")` is accepted — a
  documented deviation from Python, chosen so that the identifier folding in the
  lexer has something to show for itself;
* each statement ends the line it starts on: `print("a") print("b")` is rejected.

Anything else — another keyword, another statement type, an unsupported escape, a
string that never closes — is reported as an error with its line and column and
is never executed. Variables, arithmetic, functions, loops, imports and general
expressions are out of scope by design.

---

## 2. Architecture

```text
 .py file                      threaded stream
    |                              |
 DOS 3Dh/3Fh/3Eh ----------> SOURCE_BASE ---> lexer ---> parser ---> compiler
    load the text            4 KiB arena       |          |           |
                                                          |           v
                                                    token kinds   CODE_BASE
                                                               2 KiB of 16-bit cells
                                                                    |
                                                                    v
                                                     runtime_dispatch (lodsw / jmp ax)
                                                            |             |
                                                         op_print      op_halt
                                                            |
                                                      DOS 40h on handle 1
```

The stages never overlap in responsibility:

| Stage | Module | Produces |
| --- | --- | --- |
| load | [io/dos_file.asm](src/io/dos_file.asm) | source bytes in `SOURCE_BASE` |
| split | [io/command_line.asm](src/io/command_line.asm) | ASCIZ path in `FNAME_BASE` |
| tokenise | [frontend/lexer.asm](src/frontend/lexer.asm) | one token kind plus its value |
| parse | [frontend/parser.asm](src/frontend/parser.asm) | validation of the production |
| compile | [frontend/compiler.asm](src/frontend/compiler.asm) | cells appended to `CODE_BASE` |
| execute | [runtime/threaded_dispatch.asm](src/runtime/threaded_dispatch.asm) | DOS output |
| report | [errors/error_handler.asm](src/errors/error_handler.asm) | banner, position, excerpt |

`frontend/` never writes to the console and `runtime/` never looks at source
text: by the time the stream runs, the characters it was compiled from are
already behind it.

---

## 3. Direct-threaded execution

Each statement compiles to a fixed record of three 16-bit cells, and the program
is closed by one more cell holding the address of the HALT handler:

```text
        cell 0            cell 1        cell 2
      +---------------+-------------+--------------+ ... +---------------+
      | offset of     | address of  | byte count   |     | offset of     |
      | op_print      | the literal | of the text  |     | op_halt       |
      +---------------+-------------+--------------+ ... +---------------+
```

Because the image is assembled with `org 100h` and loaded at `CS:0100h`, an
assembled offset **is** the runtime offset, so a handler address can be stored as
data and jumped to directly. The whole dispatcher is two instructions:

```asm
runtime_dispatch:
    lodsw              ; AX = address of the next handler, SI advances by 2
    jmp  ax            ; thread straight into its code
```

A handler consumes its own operands with further `lodsw`, then `jmp
runtime_dispatch`. It is entered by an indirect jump rather than by `call`, so it
must not `ret`: control returns to the loop, never to the previous handler. HALT
is the only handler that leaves the loop; it jumps to `runtime_exit`, which
restores the frame counter and returns to `cli_run`.

Conventions that make this work in a `.COM`:

* `CS = DS = ES = SS`, set in `prog_start`, so a cell's offset is valid as both a
  code address and a data address;
* `SI` is the thread pointer and is preserved across every DOS interrupt —
  `op_print` pushes it around the write call;
* `BP` is a frame counter, not a frame pointer: a routine that keeps locals does
  `push bp` / `lea bp, [bp + 2]` and closes with `pop bp`;
* nothing rewrites code. The stream is data in a separate arena, written only by
  the compiler before execution starts.

---

## 4. Memory map and limits

One 64 KiB segment holds everything. `config.inc` is the single place where these
addresses and sizes exist.

| Region | Base | Size | Contents |
| --- | --- | --- | --- |
| PSP | `0000h` | 256 B | command tail at `0080h`/`0081h` |
| image | `0100h` | about 3 KiB | code, messages, state words |
| `SOURCE_BASE` | `2000h` | 4096 B | source text of one run |
| `STRING_BASE` | `3000h` | 2048 B | decoded literals, shared pool |
| `CODE_BASE` | `4000h` | 2048 B | threaded stream (1024 cells) |
| `IDENT_BASE` | `4800h` | 32 B | current identifier, folded to lower case |
| `FNAME_BASE` | `4880h` | 128 B | ASCIZ path taken from the command tail |
| `SCRATCH_BASE` | `4900h` | 32 B | number formatting, CRLF pair, read probe |
| stack | `5000h`–`6000h` | 4096 B | `INT 21h` and the frames above it |

Consequences worth knowing before writing a program:

* a source file larger than **4096 bytes** is refused before it is parsed;
* all literals of a run share **2047 bytes** of pool, so the total decoded text
  is the limit, not the length of one string;
* each `print` costs three cells out of the 1023 usable ones, so a program of
  more than **340 statements** overflows the threaded buffer;
* identifiers longer than 31 characters are truncated, file names longer than 127
  are refused;
* the arenas are checked against the end of the image at run time
  (`startup_check_arenas`) and against each other at build time (`LAYOUT` checks
  in `main.asm`), so an edit to `config.inc` that overlaps them fails the build
  instead of silently overwriting the stream.

---

## 5. Project layout

```text
.
|-- README.md
|-- build.bat                 Windows build
|-- build.sh                  POSIX build
|
|-- src/
|   |-- main.asm              entry point, module wiring, cli_run
|   |-- config.inc            every address, size and code
|   |-- core/                 start-up, termination, arenas
|   |-- io/                   console, DOS files, command tail
|   |-- frontend/             lexer, parser, compiler
|   |-- runtime/              dispatch loop, PRINT, HALT
|   |-- errors/               error entry points and the reporter
|   `-- data/                 state words, messages, tables
|
|-- examples/                 hello.py, prints.py, escapes.py
|-- tests/
|   |-- valid/                six programs that must run
|   |-- invalid/              nine programs that must be refused
|   `-- expected/             captured output of all nineteen cases
|-- tools/                    run_one.sh, run_tests.sh (DOSBox harness)
`-- build/                    tinyprint16.com, tpp.com
```

Each folder carries a `README.md` that explains the files inside it; each folder
also links back here.

---

## 6. Requirements

* **NASM** — tested with 3.02; any 2.15 or newer works. Only `-f bin` output is
  needed, no linker, no C runtime.
* **DOSBox**, **DOSBox-X** or real DOS/FreeDOS for running the image.
* `sh` and `diff`/`cmp` for the test harness (Git Bash on Windows is enough).

---

## 7. Building

```sh
sh build.sh                   # POSIX
```

```bat
build.bat                     # Windows
```

Both assemble the same command:

```sh
nasm -f bin -I src -o build/tinyprint16.com src/main.asm
```

A development variant prints the stage it is in, which is what was used to find
the two start-up bugs:

```sh
nasm -f bin -I src -DTRACE_STAGES=1 -o build/trace.com src/main.asm
```

---

## 8. Running under DOSBox

```dos
mount c .
c:
build\tinyprint16.com examples\hello.py
```

```text
TinyPrint16 -- direct-threaded Python interpreter
Hello, World!
```

Without long-filename support the image is `TINYPR~1.COM` and `DIR` shows
eight-character stems for everything longer (`examples\MULTIP~1.PY`), so either
start the emulator with LFN enabled — `lfn=true` in the `[dosbox]` section, which
the DOSBox-X build used for these tests did not honour on its own — or use the
short names. The harness in `tools/` sidesteps the question by copying the image
to `build\tpp.com` and by keeping every file name in this project inside 8.3.

Output goes to handle 1 with DOS function `40h`, so redirection and pipes work:

```dos
build\tinyprint16.com examples\prints.py > out.txt
```

The exit code tells DOS what happened:

| Code | Meaning |
| --- | --- |
| 0 | the program ran to its HALT token |
| 1 | a character the lexer cannot start a token from |
| 2 | a statement the grammar rejects |
| 3 | DOS or the interpreter refused: no file, cannot open, buffer full |

---

## 9. Tests

```sh
sh tools/run_tests.sh
```

The harness builds the image, copies it to `build/tpp.com`, then runs nineteen
cases in DOSBox-X, comparing the redirected output byte for byte against
`tests/expected/<name>.txt` and reading the exit code back with an
`if errorlevel` ladder:

* six valid programs (one print, several prints, an empty literal, `$` and
  escapes, mixed case, blank lines and tabs, an empty file);
* nine invalid programs (one per syntax error, plus an error on the second line);
* no argument at all, a file that does not exist, a source that overflows the
  source arena, and a program of 341 statements that overflows the threaded
  buffer. The last two fixtures are generated by the script, not committed.

Last run on 2026-11-03, NASM 3.02, DOSBox-X 2026.10.01 (SDL2) on Windows 11:
**19 passed, 0 failed**. The three files in `examples/` were run the same way and
produced the output shown in [examples/README.md](examples/README.md).

---

## 10. Known limitations

* One statement kind. The grammar is `print(literal)`; everything else is an
  error, including a second statement on the same line.
* One file per run, no includes, no stdin, no second argument.
* The string pool is never reclaimed within a run, and the arenas are fixed:
  there is no growth, and nothing is freed between runs either — `memory_reset`
  rewinds the cursors instead.
* Line endings: CR, LF and CRLF all work as line breaks, and output is always
  CRLF. A lone CR inside a literal is treated as a line break, so a carriage
  return cannot be printed.
* Errors stop the run. The first one is reported and the process exits; the rest
  of the file is never parsed.
* Real-mode only, single segment, no protected mode, no overlay, no swap: a
  program bigger than the buffers in section 4 is refused rather than paged.
* Long file names depend on the DOS environment, not on this program.
* The 8086 instruction set only: no `movzx`, no `[bx+si]` combinations, and
  memory bases restricted to `BX`, `BP`, `SI`, `DI` — which is why several
  routines say in a comment why they use `DI` rather than the obvious register.

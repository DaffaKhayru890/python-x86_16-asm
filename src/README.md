# `src/` — sources

Two files hold the skeleton, the six subdirectories the stages.

| File | Responsibility |
| --- | --- |
| [`main.asm`](main.asm) | entry point, `%include` wiring, arena layout checks, `cli_run` |
| [`config.inc`](config.inc) | every address, size, DOS function number, token kind, error code and exit code |

## Include order

`main.asm` includes the modules in the order a run touches them —
`data/`, `core/`, `io/`, `frontend/`, `runtime/`, `errors/` — so reading the file
top to bottom follows the pipeline. NASM emits one flat image, and a `-f bin`
build lays sections out in the order they are first declared, so the entry point
must be the first thing in `.text`: `main.asm` opens `section .text` and defines
`prog_start` **before** any include. That is the whole reason the file looks the
way it does.

## prog_start

```asm
prog_start:
    cli                       ; the stack is about to move
    mov  ax, cs
    mov  ss, ax
    mov  sp, STACK_TOP
    sti
    mov  ds, ax               ; one segment for code, data and stack
    mov  es, ax
    mov  bp, STACK_TOP        ; origin of the frame counter
    cld
    call startup_prepare
    call cli_run
    jmp  shutdown_exit
```

The segment and stack setup cannot live in a subroutine: `call` has already
pushed its return address onto the stack DOS handed the process, so switching
`SS` from inside one would leave that address on the old stack and the `ret`
would jump to whatever `CS:SP` then held. This is the bug that made the first
builds exit silently.

## cli_run

The one orchestration routine: reset the arenas, read the command tail, open and
load the file, compile, execute, and hand every refusal to `errors/`:

```text
memory_reset -> cmd_is_blank_line -> cmd_source_name -> dos_file_open
             -> dos_file_read -> dos_file_close -> parser_compile -> runtime_run
```

The two file-stage branches are the only place where a DOS error code is
recorded (`g_dos_err`) before the reporter is entered. A blank command tail is
not an error of the source text: it prints the usage lines and exits with code 3.

## Layout checks

`config.inc` states where each arena starts and how long it is. Seven `LAYOUT`
assertions in `main.asm` compare the end of one region with the start of the
next and refuse the build with `%error` if they overlap — a broken promise
becomes a build failure instead of an interpreter that overwrites its own
execution stream. (NASM 3.x has no `%assert` in a `-f bin` build, hence the tiny
`LAYOUT` macro.) The end of the image itself is checked at run time by
`startup_check_arenas`, because no assembler directive knows how long the
compiled program will be.

## Development build

`-DTRACE_STAGES=1` enables `%ifdef` blocks in `cli_run` that print each stage,
the source length and the number of cells generated. The markers and their text
live at the bottom of `main.asm` and add 193 bytes to the 3040 byte image. The production build
does not contain them.

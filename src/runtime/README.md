# `src/runtime` — the threaded machine

| File | Responsibility |
| --- | --- |
| [`threaded_dispatch.asm`](threaded_dispatch.asm) | enter the stream, dispatch, leave it |
| [`opcode_print.asm`](opcode_print.asm) | the PRINT handler |
| [`opcode_halt.asm`](opcode_halt.asm) | the HALT handler |

## threaded_dispatch.asm

This is the two instructions the whole design is built around:

```asm
runtime_run:
    push bp
    lea  bp, [bp + 2]
    mov  si, CODE_BASE           ; SI becomes the threaded instruction pointer
runtime_dispatch:
    lodsw                        ; AX = address of the next handler
    jmp  ax                      ; thread straight into its code
```

There is no opcode field, no decoder and no jump table indexed by a number: the
stream *is* a list of handler addresses, and the handler decides how many cells it
consumes. Adding a statement type means writing a handler and having the compiler
emit its address — the dispatch loop does not change.

`runtime_exit`, the only way out, pops the frame counter saved on entry, compares
it with the live one and reports `msg_stack_imbalance` with the offending `BP` if
a handler jumped out instead of threading back. Handlers are entered by an
indirect jump, not by `call`, so a `ret` in one would return to whatever the
stream holds next.

Register convention of the runtime, stated in the file's header comment too:

| Register | Role |
| --- | --- |
| `SI` | the threaded instruction pointer, advanced by `lodsw`, must survive DOS calls |
| `AX` | the address of the handler being entered, then scratch for it |
| `BP` | the frame counter owned by [`../core/`](../core/README.md) |
| others | scratch for the handler, never `SI` |

## opcode_print.asm

```asm
op_print:
    lodsw                ; AX = address of the literal
    mov  dx, ax
    lodsw                ; AX = byte count
    mov  cx, ax
    push si              ; the interrupt must not move the thread
    call console_write_cx
    pop  si
    jc   err_fatal_output_refused
    call console_print_crlf
    jmp  runtime_dispatch
```

Two operands, one DOS write of exactly `CX` bytes — which is why a literal may
contain `$` — then the CRLF the language promises, then straight back to the loop.
`SI` is pushed around the interrupt: `INT 21h` does not promise to preserve it, and
losing it would lose the rest of the program. A refused write is fatal, reported
with the DOS code in `AX`.

## opcode_halt.asm

```asm
op_halt:
    jmp  runtime_exit
```

One instruction, and it is the reason the stream needs no length field: the
compiler guarantees the last cell is this address, so execution can only end where
the program meant it to end.

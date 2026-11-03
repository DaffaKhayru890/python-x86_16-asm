# `src/core` — process life cycle

| File | Responsibility |
| --- | --- |
| [`startup.asm`](startup.asm) | seed the scratch slots, prove the arenas, print the banner and the usage lines |
| [`shutdown.asm`](shutdown.asm) | check that every frame unwound, then hand the exit code to DOS |
| [`memory.asm`](memory.asm) | the three arenas and the cursors that fill them |

## startup.asm

`startup_prepare` is deliberately tiny: the segment registers and the stack are
set up inline in `prog_start` (see [`../README.md`](../README.md) for why they
cannot be set up here), so what is left is filling the two-byte CRLF slot at
`CH_CRLF_SLOT`, which every line of output goes through, then the two checks.

`startup_check_arenas` compares `startup_image_end` — the first byte the image
does not occupy, defined at the bottom of `main.asm` — with `SOURCE_BASE`. If
code growth ever reached the arenas, the interpreter would overwrite its own
source text or its own execution stream, so the run is refused with
`msg_arena_overlap` before anything is read.

`startup_greet` and `startup_show_usage` are the only unconditional output.

## shutdown.asm

`shutdown_exit` is the single way out: `call shutdown_check_stack`, load
`g_exit_code` into `AL`, `INT 21h` function `4Ch`. Every error path ends here
too, so an exit code cannot be forgotten.

`shutdown_check_stack` leans on the frame convention: `BP` starts at `STACK_TOP`
and every routine that keeps locals does `push bp` / `lea bp, [bp + 2]`. A
different value at the end means a routine forgot its pops or wrote past the
stack. The failure is printed rather than papered over, and the exit code becomes
3 — damage inside the interpreter is never blamed on the source program. The
error reporter resets `BP` in `err_fatal_leave` because leaving through DOS
unwinds no frame at all, and a reported error is not that kind of bug.

## memory.asm

No allocator, no free list: the arenas are fixed ranges that a cursor fills, and
`memory_reset` rewinds the cursors at the start of a run, which is the whole of
the "management" task.

| Routine | Contract |
| --- | --- |
| `memory_reset` | rewinds `g_src_len`, `g_src_pos`, `g_code_len`, `g_str_off`, `g_str_len`, `g_pool_ptr`, the line/column counters and `g_tok` |
| `memory_store_byte` | appends `DL` to the string pool, `CF` set when `MAX_STRING_BYTES` is reached |
| `memory_emit_cell` | appends `BX` as one cell of the threaded stream, `CF` set at `MAX_PROGRAM_CELLS` |

Both appenders return `CF` rather than reporting anything, so the caller decides
which error it is. Both use `DI` as the destination pointer: `BX` has to survive
`memory_emit_cell` because it carries the value being emitted, and the 8086 can
only use `BX`, `BP`, `SI` or `DI` as a memory base.

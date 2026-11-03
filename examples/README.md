# `examples`

Three programs, run and verified under DOSBox-X on 2026-11-03.

## [`hello.py`](hello.py)

```python
print("Hello, World!")
```

```text
TinyPrint16 -- direct-threaded Python interpreter
Hello, World!
```

## [`prints.py`](prints.py)

Multiple statements execute in source order; the compiler emits one three-cell
record per statement and the stream ends with HALT.

```python
print("First")
print("Second")
print("Third")
```

```text
TinyPrint16 -- direct-threaded Python interpreter
First
Second
Third
```

The file is `prints.py`, not `multiple_prints.py`, because DOS without
long-filename support sees only the eight-character stem `MULTIP~1.PY`. Keeping
every file name in this project within 8.3 means the examples work on the emulators
and on real DOS without configuration.

## [`escapes.py`](escapes.py)

```python
print("Price: $100")
print("Quoted: \"Hello\"")
print("Backslash: C:\\tmp")
print("")
```

```text
TinyPrint16 -- direct-threaded Python interpreter
Price: $100
Quoted: "Hello"
Backslash: C:\tmp

```

The `$` in the first line is the reason output uses DOS function `40h` instead of
the string function `09h`, which would have stopped there. The last statement
prints an empty literal, which is an empty line: the length is written to the
stream, so there is nothing to special-case.

## Running them

```dos
mount c .
c:
build\tinyprint16.com examples\hello.py
```

#!/bin/sh
# Build the interpreter, then run every program under tests/ inside DOSBox-X and
# compare what it wrote, together with the code it handed back to DOS, with the
# matching file in tests/expected.
#
# The two buffer limits are checked with fixtures that are generated rather than
# committed, because they are thousands of bytes of the same line.
#
# Exit status is nonzero as soon as anything differs.

set -u
cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0

sh build.sh || exit 1

# DOS without long filename support cannot open a thirteen character command, so
# the emulator always runs the eight character copy of the image.
cp build/tinyprint16.com build/tpp.com || exit 1

write_lines() {                     # write_lines <count> <text> <file>
    count=$1
    text=$2
    file=$3
    : > "$file"
    index=0
    while [ "$index" -lt "$count" ]
    do
        printf '%s\r\n' "$text" >> "$file"
        index=$((index + 1))
    done
}

run_case() {                        # run_case <name> <exit-code> [source-file]
    name=$1
    want=$2
    shift 2
    if ! out=$(sh tools/run_one.sh "build/cap_$name.txt" "$@"); then
        echo "FAIL $name: the emulator did not finish"
        fail=$((fail + 1))
        return
    fi
    got=$(printf '%s\n' "$out" | sed -n 's/^exit_code=//p')
    if [ "$got" != "$want" ]; then
        echo "FAIL $name: exit code $got, expected $want"
        fail=$((fail + 1))
        return
    fi
    if cmp -s "build/cap_$name.txt" "tests/expected/$name.txt"; then
        echo "ok   $name"
        pass=$((pass + 1))
    else
        echo "FAIL $name"
        diff -u "tests/expected/$name.txt" "build/cap_$name.txt" | sed -n '1,20p'
        fail=$((fail + 1))
    fi
}

for source in tests/valid/*.py
do
    run_case "$(basename "$source" .py)" 0 "$source"
done

# A character that starts no token exits with 1, a statement the grammar rejects
# with 2, and a failure of DOS or of the interpreter itself with 3.
for source in tests/invalid/*.py
do
    name=$(basename "$source" .py)
    case $name in
    badchar) code=1 ;;
    *)       code=2 ;;
    esac
    run_case "$name" "$code" "$source"
done

run_case usage 3
run_case missing 3 tests/invalid/nosuch.py
write_lines 300 'print("0123456789")' build/big.py
write_lines 341 'print("")' build/many.py
run_case overflow_source 3 build/big.py
run_case overflow_thread 3 build/many.py

# The captures and the generated fixtures are intermediates of this script, not
# results: build/ keeps only the two images when the run is over.
rm -f build/cap_*.txt build/out.txt build/exit.txt build/done.txt
rm -f build/run_one.conf build/big.py build/many.py

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]

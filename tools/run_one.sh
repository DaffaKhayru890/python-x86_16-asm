#!/bin/sh
# Run the interpreter once inside DOSBox-X and capture what it wrote.
#
# The emulator starts with its window paused and quits from its own [autoexec]
# block, so one headless run is enough to compare redirected output against
# tests/expected. build/done.txt comes from the last line of that block: when it
# is missing, the run never completed.
#
# Usage: sh tools/run_one.sh <capture-file> [source-file]

set -u
cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd -W 2>/dev/null || pwd)

DOSBOX=${DOSBOX_X:-}
if [ -z "$DOSBOX" ]; then
    for candidate in \
        "/c/Program Files/dosbox-x/dosbox-x.exe" \
        "/Applications/Dosbox-X.app/Contents/MacOS/Dosbox-X" \
        dosbox-x \
        dosbox
    do
        if command -v "$candidate" >/dev/null 2>&1; then
            DOSBOX=$candidate
            break
        fi
    done
fi
if [ -z "$DOSBOX" ]; then
    echo "run_one: no DOSBox found; set DOSBOX_X to the executable" >&2
    exit 2
fi

CAPTURE=$1
shift
ARGS=""
for argument in "$@"
do
    ARGS="$ARGS$(echo "$argument" | tr '/' '\\')"
done

mkdir -p build
rm -f "$CAPTURE" build/out.txt build/exit.txt build/done.txt

cat > build/run_one.conf <<EOF
[sdl]
fullscreen=false
priority=infront,paused
[dosbox]
machine=svga_s3
memsize=16
[autoexec]
mount c "$ROOT"
c:
build\\tpp.com $ARGS > build\\out.txt
if errorlevel 1 echo 1 >> build\\exit.txt
if errorlevel 2 echo 2 >> build\\exit.txt
if errorlevel 3 echo 3 >> build\\exit.txt
echo finished > build\\done.txt
exit
EOF

"$DOSBOX" -conf "build/run_one.conf" >/dev/null 2>&1
if [ ! -f build/done.txt ]; then
    echo "run_one: DOSBox-X did not finish the run" >&2
    exit 3
fi
mv build/out.txt "$CAPTURE"

# The ladder above leaves one line per threshold the program reached, so its
# last line is the exit code. The built-in shell of DOSBox has no ERRORLEVEL
# variable to read, and it applies the redirection even when the test fails, so a
# clean run is the run that leaves the file empty.
if [ -s build/exit.txt ]; then
    CODE=$(tail -1 build/exit.txt | tr -d '\r\n ')
else
    CODE=0
fi
echo "exit_code=$CODE"

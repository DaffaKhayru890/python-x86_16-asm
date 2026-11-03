#!/bin/sh
# TinyPrint16 -- builds the DOS .COM image with NASM from the project root.
set -e

cd "$(dirname "$0")"

ASM=${ASM:-nasm}

if ! command -v "$ASM" >/dev/null 2>&1; then
    echo "build failed: nasm is not on PATH" >&2
    echo "install it, or set ASM to the full path of nasm" >&2
    exit 1
fi

mkdir -p build
"$ASM" -f bin -I src -o build/tinyprint16.com src/main.asm
echo "built build/tinyprint16.com"

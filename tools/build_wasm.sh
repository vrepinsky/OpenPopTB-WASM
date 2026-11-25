#!/bin/sh
# Builds the WebAssembly version:
#   tools/build_wasm.sh        headless, runs under Node.js     -> build-wasm/PopulousTB.js + .wasm
#   tools/build_wasm.sh --web  browser page (serve with tools/serve_web.py) -> build-web/
# Needs gen/ (run build.sh or recomp/gen.py first) and the Emscripten SDK:
#   emcc in PATH, or EMSDK=/path/to/emsdk (its emsdk_env.sh is sourced).
#   emsdk needs Python >= 3.10; on macOS: EMSDK_PYTHON=/opt/homebrew/bin/python3.13
# usage: tools/build_wasm.sh [--web] [Debug|RelWithDebInfo|Release]
#   default: Release for --web (11 MB .wasm, ~2 MB gzipped), RelWithDebInfo for Node (89 MB, with
#   DWARF debug info: C source lines in Chrome DevTools with the C/C++ DevTools Support extension).
#   Every build writes PopulousTB.js.symbols (function index -> f_<x86 address>) for crash stacks.
set -e
P="$(cd "$(dirname "$0")/.." && pwd)"
B=build-wasm; WEB=OFF; TYPE=RelWithDebInfo
if [ "$1" = "--web" ]; then B=build-web; WEB=ON; TYPE=Release; shift; fi
if ! command -v emcc >/dev/null; then
  [ -n "$EMSDK" ] && [ -f "$EMSDK/emsdk_env.sh" ] || { echo "emcc not found: set EMSDK=/path/to/emsdk" >&2; exit 1; }
  . "$EMSDK/emsdk_env.sh" >/dev/null 2>&1
fi
ls "$P"/gen/*.c >/dev/null 2>&1 || { echo "gen/ is empty: generate the C first (build.sh)" >&2; exit 1; }
emcmake cmake -S "$P" -B "$P/$B" -G Ninja -DCMAKE_BUILD_TYPE="${1:-$TYPE}" -DPOPTB_WEB=$WEB >/dev/null
ninja -C "$P/$B" poptb

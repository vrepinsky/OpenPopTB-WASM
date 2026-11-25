#!/bin/sh
# Build and run in one command. Each step only redoes what changed.
#   ./play.sh [web] [options]   browser: generates gen/ if needed, builds build-web/, serves, opens Chrome
#   ./play.sh native [options]  native macOS reference build (build/), runs it
# options:
#   --game DIR     game folder (with popTB.exe). Remembered in .poptb-game for next time.
#   --no-build     skip building
#   --no-open      don't open the browser (web)
#   --port N       server port (web, default 8123)
#   -- ARGS...     extra arguments for the game (native), e.g. -- --script "3000:key:Escape"
# env: EMSDK (default: ../emsdk or ~/emsdk), EMSDK_PYTHON (default: newest python3.1x on PATH)
set -e
P="$(cd "$(dirname "$0")" && pwd)"
MODE=web; GAME=""; BUILD=1; OPEN=1; PORT=8123
case "$1" in web|native) MODE=$1; shift ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --game) GAME="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    --no-open) OPEN=0; shift ;;
    --port) PORT="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (see ./play.sh --help)" >&2; exit 2 ;;
  esac
done

# --- game folder: --game, then .poptb-game, POPTB_GAME, game/
[ -n "$GAME" ] || { [ -f "$P/.poptb-game" ] && GAME="$(cat "$P/.poptb-game")"; } || true
[ -n "$GAME" ] || GAME="${POPTB_GAME:-$P/game}"
case "$GAME" in "~"/*) GAME="$HOME/${GAME#\~/}" ;; esac
if [ ! -f "$GAME/popTB.exe" ]; then
  echo "game folder not found (no popTB.exe in '$GAME')." >&2
  echo "run once with: ./play.sh --game /path/to/Populous-The-Beginning" >&2; exit 1
fi
GAME="$(cd "$GAME" && pwd)"
echo "$GAME" > "$P/.poptb-game"
echo "== game: $GAME"

# --- gen/: the C recompiled from popTB.exe (+ QMixer.dll, WEANETR.dll)
if [ $BUILD = 1 ] && ! ls "$P"/gen/*.c >/dev/null 2>&1; then
  if [ ! -x "$P/.venv/bin/python" ]; then
    echo "== setting up .venv (capstone, pefile)"
    python3 -m venv "$P/.venv" && "$P/.venv/bin/pip" install -q capstone pefile
  fi
  echo "== recompiling popTB.exe into gen/ (~15 s)"
  "$P/.venv/bin/python" -I "$P/recomp/gen.py" "$P/gen" "$GAME/popTB.exe:$P/re/export/functions.tsv" \
    "$GAME/QMixer.dll" "$GAME/WEANETR.dll"
fi

if [ $MODE = native ]; then
  if [ $BUILD = 1 ]; then
    echo "== building native (build/)"
    [ -f "$P/build/build.ninja" ] || cmake -S "$P" -B "$P/build" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo >/dev/null
    ninja -C "$P/build" poptb
  fi
  echo "== running (Cmd+Q quits)"
  exec "$P/build/PopulousTB.app/Contents/MacOS/PopulousTB" --data "$GAME" "$@"
fi

# --- web
if [ $BUILD = 1 ]; then
  if ! command -v emcc >/dev/null; then
    for d in "$EMSDK" "$P/../emsdk" "$HOME/emsdk"; do
      [ -n "$d" ] && [ -f "$d/emsdk_env.sh" ] && { EMSDK="$(cd "$d" && pwd)"; break; }
    done
    [ -n "$EMSDK" ] && [ -f "$EMSDK/emsdk_env.sh" ] || {
      echo "Emscripten not found: install emsdk next to this repo (../emsdk) or set EMSDK=/path/to/emsdk" >&2; exit 1; }
    export EMSDK
  fi
  if [ -z "$EMSDK_PYTHON" ]; then   # emsdk needs Python 3.10+; macOS ships 3.9
    for v in 3.14 3.13 3.12 3.11 3.10; do
      command -v python$v >/dev/null && { export EMSDK_PYTHON="$(command -v python$v)"; break; }
    done
  fi
  echo "== building web (build-web/)"
  "$P/tools/build_wasm.sh" --web
fi
[ -f "$P/build-web/PopulousTB.wasm" ] || { echo "build-web/ is empty: run without --no-build" >&2; exit 1; }

URL="http://localhost:$PORT/?dev"
browse() { open -a "Google Chrome" "$1" 2>/dev/null || open "$1"; }
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  # a server is already running there (it serves build-web/ uncached, so it picks up the new build)
  echo "== a server is already running on port $PORT: $URL"
  [ $OPEN = 1 ] && browse "$URL"
  exit 0
fi
echo "== serving $URL (Ctrl+C stops)"
[ $OPEN = 1 ] && ( sleep 1; browse "$URL" ) &
exec python3 "$P/tools/serve_web.py" --port "$PORT" --game "$GAME"

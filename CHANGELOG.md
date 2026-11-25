# Changelog

Changes in this fork. Format: [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]
### Fork: OpenPopTB-WASM
- Forked from OpenPopTB-MacOS 0.2.1 as an attempt at a browser (WebAssembly) port. Plan:
  `docs/wasm/PLAN.md`.
- Removed what the fork does not need: release packaging, signing and notarization
  (`tools/package_release.sh`, `tools/entitlements.plist`, `tools/release_notes.sh`, the GitHub
  release workflow), app icons (`assets/`, `tools/make_icons.py`), README media, the old
  hand-written terrain viewer (`src/`) and one-off recompiler census scripts.
- `POPTB_STATS=1`: memory and stack statistics (`docs/DEBUGGING.md`).
- `FUZZ_WASM=1 tools/fuzz.sh`: runs the instruction fuzzer as wasm32 under Node.js too and compares
  the failing forms with native (identical).
- WebAssembly build that runs headless under Node.js (`tools/build_wasm.sh`, `tools/run_wasm.sh`):
  intro, main menu and Rolling Demo run.
- Browser build (`tools/build_wasm.sh --web`, `web/`, `tools/serve_web.py`): the game runs in Chrome
  and draws on a canvas, loading the player's game folder into the tab. Keyboard and mouse work
  (Cmd+Enter: fullscreen with the mouse captured; hold Escape to leave). Absolute mouse input
  (browser and input scripts) moves from the game's real cursor position, so it no longer drifts.
- Sound in the browser: sound effects, music and FMV audio through an AudioWorklet. It starts with
  the folder choice (or the first click or key press with `?dev`).
- `tools/build_wasm.sh --web` builds Release by default: 11 MB `.wasm` instead of 89 MB, plus a
  symbol map (`PopulousTB.js.symbols`) for reading crash stacks.
- Browser saves and settings persist across reloads (IndexedDB). On the first run they start from
  the chosen folder's SAVE files.
- New CMake options, also usable natively: `POPTB_HEADLESS` (no window, scripted input and
  screenshots) and `POPTB_GUEST_WINDOW` (512 MB guest memory, the WebAssembly layout).
- Runtime portability: monotonic clock instead of `mach_absolute_time`, macOS-only code behind
  `#ifdef`, smaller thread stacks on WebAssembly, clean exit from any thread (`rt_exit`).
- `./play.sh`: build and run in one command. Recompiles `gen/` if missing, builds the browser
  version, serves it and opens Chrome; `./play.sh native` does the same for the native build. It
  remembers the game folder (`.poptb-game`) and finds emsdk and a recent Python by itself.
- Fixed: the loopback fallback address for LAN broadcasts was built wrong on non-Apple platforms
  (WebAssembly).
- Removed the upstream-only parts the browser port does not use: the Direct3D build (`d3d.c`,
  `gpu.c`, `re/export_d3d/`, `re/d3d_usage.md`, `tools/d3d_compare.sh`), the native app packaging and
  first-launch recompile (`build.sh`, `tools/package.sh`, `runtime/prepare.c`, `POPTB_PREBUILT`,
  `--installer`), and the upstream roadmap, multiplayer and file format docs. `./play.sh` replaces `build.sh` and
  now does its game file hash check. The native dev build stays as the reference.

## Upstream history
Releases up to 0.2.1 are OpenPopTB-MacOS's: see its
[changelog](https://github.com/iagodemacedo/OpenPopTB-MacOS/blob/main/CHANGELOG.md).

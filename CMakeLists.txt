cmake_minimum_required(VERSION 3.24)
set(CMAKE_OSX_DEPLOYMENT_TARGET 12.0 CACHE STRING "Oldest macOS supported")
project(openpoptb VERSION 0.2.1 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(EMSCRIPTEN)
  # WebAssembly build (emcmake cmake ...): headless under Node.js with direct access to the host file
  # system, or with POPTB_WEB a browser page (web/) that draws the frames on a canvas.
  # SDL3 comes from the Emscripten port (audio only).
  option(POPTB_WEB "Browser build instead of Node.js" OFF)
  set(POPTB_HEADLESS ON CACHE BOOL "" FORCE)
  set(POPTB_SDL3 "--use-port=sdl3")
  add_compile_options(-pthread ${POPTB_SDL3})
else()
  find_package(SDL3 REQUIRED CONFIG)
endif()

# Recompiled port: x86 code translated to C (gen*/) + Win32/DirectX runtime on top of SDL3.
# One target per game executable: Populous: The Beginning and the Undiscovered Worlds expansion.
option(POPTB_GEN_DEBUG "Build the generated code without optimization (exact lines in the debugger)" OFF)
# Compact 512 MB guest address space, as used by the WebAssembly build (runtime/rt.h). Natively, any
# guest access outside the window faults, which makes this the bounds check for the web layout.
option(POPTB_GUEST_WINDOW "Use the compact WebAssembly guest memory layout" OFF)
option(POPTB_HEADLESS "No window: scripted input and screenshots only (runtime/plat_headless.c)" OFF)
file(GLOB RT_SRC CONFIGURE_DEPENDS runtime/*.c)
# one platform layer: SDL3 window (plat.c) or headless (plat_headless.c)
if(POPTB_HEADLESS)
  list(REMOVE_ITEM RT_SRC ${CMAKE_CURRENT_SOURCE_DIR}/runtime/plat.c)
else()
  list(REMOVE_ITEM RT_SRC ${CMAKE_CURRENT_SOURCE_DIR}/runtime/plat_headless.c)
endif()
function(poptb_target name gendir exe outname bundle)
  file(GLOB GEN_SRC CONFIGURE_DEPENDS ${gendir}/*.c)
  if(NOT GEN_SRC)
    return()
  endif()
  add_executable(${name} MACOSX_BUNDLE ${RT_SRC} ${GEN_SRC})
  target_include_directories(${name} PRIVATE runtime ${gendir})
  if(EMSCRIPTEN)
    target_link_options(${name} PRIVATE -pthread ${POPTB_SDL3}
        -sPROXY_TO_PTHREAD -sPTHREAD_POOL_SIZE=16 -sEXIT_RUNTIME
        -sSTACK_SIZE=1MB -sDEFAULT_PTHREAD_STACK_SIZE=2MB
        # PopulousTB.js.symbols: function index -> name (f_<x86 address>), to read crash stacks of
        # builds without debug info; not loaded by the page
        --emit-symbol-map)
    if(POPTB_WEB)
      # fixed memory: no growth, so the page's views of the shared heap never go stale. Game files
      # are written into the in-memory file system by web/main.js before main() is called
      target_compile_definitions(${name} PRIVATE POPTB_WEB)
      target_link_options(${name} PRIVATE -sENVIRONMENT=web,worker -sINITIAL_MEMORY=1GB
          -sINVOKE_RUN=0 -sFORCE_FILESYSTEM -sEXPORTED_RUNTIME_METHODS=callMain,FS,IDBFS -lidbfs.js)
    else()
      target_link_options(${name} PRIVATE -sALLOW_MEMORY_GROWTH -sINITIAL_MEMORY=768MB
          -sMAXIMUM_MEMORY=2GB -sNODERAWFS -sENVIRONMENT=node)
    endif()
    target_link_libraries(${name} PRIVATE m)
  else()
    target_link_libraries(${name} PRIVATE SDL3::SDL3 m)
  endif()
  target_compile_definitions(${name} PRIVATE POPTB_EXE="${exe}")
  if(POPTB_GUEST_WINDOW)
    target_compile_definitions(${name} PRIVATE POPTB_GUEST_WINDOW)
  endif()
  target_compile_options(${name} PRIVATE -fno-strict-aliasing -fwrapv -Wno-parentheses -Wno-unused-value)
  if(POPTB_GEN_DEBUG)
    set_source_files_properties(${GEN_SRC} TARGET_DIRECTORY ${name} PROPERTIES COMPILE_OPTIONS "-O0;-g;-w")
  else()
    set_source_files_properties(${GEN_SRC} TARGET_DIRECTORY ${name} PROPERTIES COMPILE_OPTIONS "-O1;-w")
  endif()
  set_target_properties(${name} PROPERTIES
      OUTPUT_NAME "${outname}"
      MACOSX_BUNDLE_GUI_IDENTIFIER "local.openpoptb.${name}"
      MACOSX_BUNDLE_BUNDLE_NAME "${bundle}"
      MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}")
endfunction()
poptb_target(poptb gen popTB.exe PopulousTB "Populous TB")
poptb_target(poptbuw gen_uw popTBUW.exe PopulousUW "Populous UW")


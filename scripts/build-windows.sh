#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

build_dir="$repo_root/build/windows"
build_type="Release"
clean="no"
generator=""

usage() {
  cat <<'EOF'
Usage: scripts/build-windows.sh [options]

Options:
  --release          Build with CMAKE_BUILD_TYPE=Release (default)
  --debug            Build with CMAKE_BUILD_TYPE=Debug
  --build-dir DIR    Build directory, default ./build/windows
  --clean            Remove build directory before configuring
  --generator GEN    CMake generator (e.g. Ninja)
  --help             Show this help

Requirements:
  mingw-w64
  cmake
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --release)
      build_type="Release"
      ;;
    --debug)
      build_type="Debug"
      ;;
    --build-dir)
      shift
      [ "$#" -gt 0 ] || {
        echo "Missing value for --build-dir" >&2
        exit 1
      }
      build_dir="$1"
      ;;
    --generator)
      shift
      [ "$#" -gt 0 ] || {
        echo "Missing value for --generator" >&2
        exit 1
      }
      generator="$1"
      ;;
    --clean)
      clean="yes"
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

case "$build_dir" in
  /*) ;;
  *) build_dir="$repo_root/$build_dir" ;;
esac

if [ "$clean" = "yes" ]; then
  rm -rf "$build_dir"
fi

toolchain_file="$repo_root/cmake/mingw-w64-toolchain.cmake"

if [ ! -f "$toolchain_file" ]; then
  echo "Toolchain file not found:"
  echo "  $toolchain_file"
  exit 1
fi

cmake_args=(
  -S "$repo_root"
  -B "$build_dir"
  -DCMAKE_BUILD_TYPE="$build_type"
  -DCMAKE_TOOLCHAIN_FILE="$toolchain_file"
)

if [ -n "$generator" ]; then
  cmake_args+=(-G "$generator")
fi

cmake "${cmake_args[@]}"

cmake --build "$build_dir" --config "$build_type"

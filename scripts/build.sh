#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

build_dir="$repo_root/build"
build_type="Debug"
use_openssl="OFF"
clean="no"

usage() {
  cat <<'EOF'
Usage: scripts/build.sh [options]

Options:
  --release          Build with CMAKE_BUILD_TYPE=Release
  --debug            Build with CMAKE_BUILD_TYPE=Debug
  --openssl          Build with OpenSSL instead of Mongoose built-in TLS
  --build-dir DIR    Build directory, default ./build
  --clean            Remove the build directory before configuring
  --help             Show this help
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
    --openssl)
      use_openssl="ON"
      ;;
    --build-dir)
      shift
      if [ "$#" -eq 0 ]; then
        echo "Missing value for --build-dir" >&2
        exit 1
      fi
      build_dir="$1"
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

cmake -S "$repo_root" -B "$build_dir" \
  -DCMAKE_BUILD_TYPE="$build_type" \
  -DUSE_OPENSSL="$use_openssl"

cmake --build "$build_dir"

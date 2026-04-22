#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_BIN="$ROOT_DIR/scripts/toolchains/linux-llvm-bin"

export PATH="$TOOLCHAIN_BIN:$PATH"

exec flutter "$@"

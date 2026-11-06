#!/usr/bin/env bash
# Fetch the external 6502 conformance test suite (GPL, not vendored here).
set -euo pipefail
dir="$(dirname "$0")/../crates/mos6502/tests/data"
mkdir -p "$dir"
curl -sSL -o "$dir/6502_functional_test.bin" \
  https://github.com/Klaus2m5/6502_65C02_functional_tests/raw/master/bin_files/6502_functional_test.bin
echo "fetched $dir/6502_functional_test.bin"

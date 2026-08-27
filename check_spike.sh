#!/usr/bin/env bash
# Correctness gate: run each benchmark on host lua and on spike+pk (fast
# path, NO tracing — --trace forces spike's slow path on this branch),
# and diff the outputs.
set -e
PK=$RISCV/riscv64-unknown-elf/bin/pk
for b in "nbody.lua 1000" "fannkuch.lua 7" "binarytrees.lua 10" "sieve.lua 100000"; do
  set -- $b
  ./lua-host/src/lua bench/$1 $2 > /tmp/lua.host.out
  spike $PK lua-riscv/src/lua bench/$1 $2 2>/dev/null | grep -v "^bbl loader" > /tmp/lua.spike.out
  if diff -q /tmp/lua.host.out /tmp/lua.spike.out >/dev/null; then
    echo "MATCH $1"
  else
    echo "DIFF  $1"; diff /tmp/lua.host.out /tmp/lua.spike.out | head; exit 1
  fi
done

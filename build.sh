#!/usr/bin/env bash
# Build host (oracle) and static riscv64 Lua 5.4.7, default switch dispatch.
# Usage: source ../../env.sh first (needs riscv64-unknown-linux-gnu-gcc).
set -e
[ -d lua-5.4.7 ] || { curl -sO https://www.lua.org/ftp/lua-5.4.7.tar.gz && tar xzf lua-5.4.7.tar.gz; }
rm -rf lua-host lua-riscv
cp -r lua-5.4.7 lua-host
cp -r lua-5.4.7 lua-riscv
make -C lua-host/src posix CC="gcc -std=gnu99" MYCFLAGS="-O2" -j8
make -C lua-riscv/src posix -j8 \
  CC="riscv64-unknown-linux-gnu-gcc -std=gnu99" \
  AR="riscv64-unknown-linux-gnu-ar rcu" RANLIB="riscv64-unknown-linux-gnu-ranlib" \
  MYCFLAGS="-O2 -g -static" MYLDFLAGS="-static"

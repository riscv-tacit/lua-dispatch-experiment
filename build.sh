#!/usr/bin/env bash
# Build the Lua 5.4.7 interpreters used in the dispatch case study.
#
#   ./build.sh act1     stock switch-dispatch binaries: lua-host (oracle) and lua-riscv
#                       (-O2 -g -static, i.e. GCC's cross-jumping merges the handler tails
#                       into ~15 shared dispatch sites -- the Act 1 finding)
#   ./build.sh fuse     the fusion trees, all with -fno-crossjumping so every handler owns
#                       its dispatch jr: lua-fuse-base, lua-fuse-mulmul,
#                       lua-fuse-mulmul-muladd, lua-mulmul-gt127, lua-fuse-leimul,
#                       lua-leimul-gt127. Each tree is a hand-edited copy of lua-5.4.7
#                       (only lvm.c differs); its manifest.json records the edit, the flags
#                       and the md5 of the binary that was run on the FPGA. The build here
#                       must reproduce that md5, and the script checks it.
#   ./build.sh fuse lua-fuse-mulmul     one tree
#   ./build.sh all
#
# Usage: source ../../env.sh first (needs riscv64-unknown-linux-gnu-gcc 13.2.0; a
# different compiler version will not reproduce the manifest md5s).
set -e
cd "$(dirname "$0")"
RV="riscv64-unknown-linux-gnu-"
FUSE_TREES="lua-fuse-base lua-fuse-mulmul lua-fuse-mulmul-muladd lua-mulmul-gt127 lua-fuse-leimul lua-leimul-gt127"
FUSE_CFLAGS="-O2 -g -static -fno-crossjumping"

build_riscv() {  # tree cflags
  make -C "$1/src" clean >/dev/null 2>&1 || true
  make -C "$1/src" posix -j"$(nproc)" \
    CC="${RV}gcc -std=gnu99" AR="${RV}ar rcu" RANLIB="${RV}ranlib" \
    MYCFLAGS="$2" MYLDFLAGS="-static" >/dev/null
}

act1() {
  [ -d lua-5.4.7 ] || { curl -sO https://www.lua.org/ftp/lua-5.4.7.tar.gz && tar xzf lua-5.4.7.tar.gz; }
  rm -rf lua-host lua-riscv
  cp -r lua-5.4.7 lua-host
  cp -r lua-5.4.7 lua-riscv
  make -C lua-host/src posix CC="gcc -std=gnu99" MYCFLAGS="-O2" -j"$(nproc)" >/dev/null
  build_riscv lua-riscv "-O2 -g -static"
  echo "act1: lua-host/src/lua, lua-riscv/src/lua (cross-jumped)"
}

fuse() {
  local trees="${*:-$FUSE_TREES}" rc=0
  for t in $trees; do
    [ -f "$t/manifest.json" ] || { echo "$t: no manifest.json" >&2; rc=1; continue; }
    local want; want=$(python3 -c "import json;print(json.load(open('$t/manifest.json'))['md5'])")
    build_riscv "$t" "$FUSE_CFLAGS"
    local got; got=$(md5sum < "$t/src/lua" | cut -d' ' -f1)
    if [ "$got" = "$want" ]; then
      printf '%-24s ok      %s\n' "$t" "${got:0:12}"
    else
      printf '%-24s MISMATCH built %s, manifest %s\n' "$t" "${got:0:12}" "${want:0:12}"; rc=1
    fi
  done
  return $rc
}

case "${1:-}" in
  act1) act1 ;;
  fuse) shift; fuse "$@" ;;
  all)  act1; fuse ;;
  *) sed -n '2,20p' "$0"; exit 2 ;;
esac

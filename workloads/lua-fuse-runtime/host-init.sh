#!/bin/bash
# Install the four arm binaries from their interpreter trees and build the timing
# harness. build.sh must have run first (./build.sh fuse), which is also what verifies
# each tree's .text against its manifest.
set -e
cd "$(dirname "$0")"
D=overlay/root/lua-dispatch
install -m 755 ../../lua-fuse-base/src/lua          $D/lua-base
install -m 755 ../../lua-fuse-mulmul/src/lua        $D/lua-mulmul
install -m 755 ../../lua-fuse-mulmul-muladd/src/lua $D/lua-mmadd
install -m 755 ../../lua-fuse-leimul/src/lua        $D/lua-leimul
make -C $D time-run

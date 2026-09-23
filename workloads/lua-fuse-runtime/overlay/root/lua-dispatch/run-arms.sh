#!/bin/sh
# Headline runtime for the four dispatch-fusion arms: mandelbrot 900 under each
# interpreter, untraced. One warm-up pass over all four (discarded: it pays the cold
# page cache and predictor state) then three measured passes. Arms are interleaved
# within a pass rather than run back-to-back, so any drift over the run spreads across
# the arms instead of loading onto one of them.
cd /root/lua-dispatch
N=900
ARMS="base mulmul mmadd leimul"

for a in $ARMS; do ./time-run $a warmup ./lua-$a bench/mandelbrot.lua $N > /dev/null; done
for rep in 1 2 3; do
  for a in $ARMS; do
    ./time-run $a $rep ./lua-$a bench/mandelbrot.lua $N
  done
done
echo LUA_FUSE_RUNTIME_DONE

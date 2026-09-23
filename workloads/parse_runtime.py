#!/usr/bin/env python3
"""Summarize the RESULT lines a lua-fuse-runtime uartlog leaves behind.

  ./parse_runtime.py <results-workload>/lua-fuse-runtime/uartlog

Reports per-arm median cycles and instructions over the measured reps (the warm-up
pass writes to /dev/null and never reaches the log), and each arm's delta against
lua-fuse-base. Cycles are the headline: they are what the manifests' predictions are
stated in, and unlike wall time they do not depend on the target clock.
"""
import re, statistics, sys

ORDER = ['base', 'mulmul', 'mmadd', 'leimul']
LABEL = {'base': 'baseline', 'mulmul': 'mul-mul', 'mmadd': 'mul-mul + mul-add',
         'leimul': 'lei-mul'}
PAT = re.compile(r'RESULT arm=(\S+) rep=(\S+) cycles=(\d+) instret=(\d+) '
                 r'wall=([\d.]+) status=(\d+)')

def main(path):
    runs = {}
    bad = []
    for line in open(path, errors='replace'):
        m = PAT.search(line)
        if not m:
            continue
        arm, rep, cyc, ins, wall, st = m.groups()
        if st != '0':
            bad.append((arm, rep, st))
        runs.setdefault(arm, []).append((int(cyc), int(ins), float(wall)))

    if not runs:
        sys.exit(f'no RESULT lines in {path}')
    if bad:
        print('WARNING: nonzero exit status:', bad)

    base = statistics.median(c for c, _, _ in runs.get('base', [(0, 0, 0)]))
    w = max(len(LABEL[a]) for a in ORDER if a in runs)
    print(f'{"arm":<{w}}  {"n":>2}  {"cycles (median)":>16}  {"vs base":>9}  '
          f'{"instret":>14}  {"vs base":>9}  {"spread":>7}')
    for a in ORDER:
        if a not in runs:
            continue
        cyc = [c for c, _, _ in runs[a]]
        ins = [i for _, i, _ in runs[a]]
        mc, mi = statistics.median(cyc), statistics.median(ins)
        bi = statistics.median(i for _, i, _ in runs['base']) if 'base' in runs else 0
        spread = (max(cyc) - min(cyc)) / mc * 100 if mc else 0
        dc = f'{(mc / base - 1) * 100:+.2f}%' if base else '-'
        di = f'{(mi / bi - 1) * 100:+.2f}%' if bi else '-'
        print(f'{LABEL[a]:<{w}}  {len(cyc):>2}  {mc:>16,}  {dc:>9}  {mi:>14,}  '
              f'{di:>9}  {spread:>6.2f}%')

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__))

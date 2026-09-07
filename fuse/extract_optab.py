#!/usr/bin/env python3
"""Extract handler-entry address -> opcode name from a built lua binary.

Reads lvm.c's `disptab` (the computed-goto jump table: NUM_OPCODES code pointers, in
lopcodes.h enum order) straight out of the ELF. Every variant needs its own table, and
deriving it mechanically is what keeps a decode config honest -- a hand-maintained table
is how fused arrivals went missing in the first place.

  ./extract_optab.py lua-fuse-base/src/lua -o .../configs/lua/lua_optab_fusebase.json
"""
import argparse
import json
import re
import struct
import sys
from pathlib import Path

from elftools.elf.elffile import ELFFile

HERE = Path(__file__).resolve().parent
LOPCODES = HERE.parent / 'lua-5.4.7/src/lopcodes.h'


def opcode_names():
    names = []
    for line in LOPCODES.read_text().splitlines():
        m = re.match(r'\s*(OP_\w+)', line)
        if m and 'NUM_OPCODES' not in line:
            n = m.group(1)
            if n not in names:
                names.append(n)
    return names


def read_at(elf, vaddr, size):
    for seg in elf.iter_segments():
        if seg['p_type'] != 'PT_LOAD':
            continue
        lo, hi = seg['p_vaddr'], seg['p_vaddr'] + seg['p_filesz']
        if lo <= vaddr and vaddr + size <= hi:
            return seg.data()[vaddr - lo: vaddr - lo + size]
    sys.exit(f'vaddr 0x{vaddr:x} not in any PT_LOAD segment')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('binary')
    ap.add_argument('-o', '--out')
    a = ap.parse_args()
    names = opcode_names()

    with open(a.binary, 'rb') as f:
        elf = ELFFile(f)
        sym = None
        for sec in elf.iter_sections():
            if sec.header['sh_type'] != 'SHT_SYMTAB':
                continue
            for s in sec.iter_symbols():
                if re.fullmatch(r'disptab(\.\d+)?', s.name):
                    sym = s
        if sym is None:
            sys.exit('no `disptab` symbol (GCC static, may be disptab.N) -- jumptable build with symbols?')
        addr, size = sym['st_value'], sym['st_size']
        n = size // 8
        if n != len(names):
            print(f'warning: disptab holds {n} entries, lopcodes.h lists {len(names)}', file=sys.stderr)
        raw = read_at(elf, addr, size)

    ptrs = struct.unpack('<%dQ' % n, raw)
    tab = {}
    for name, p in zip(names, ptrs):
        # decoder configs use bare opcode names (MOVE, not OP_MOVE)
        tab.setdefault(hex(p), name[3:] if name.startswith('OP_') else name)
    dup = n - len(tab)
    out = json.dumps(tab, indent=1)
    if a.out:
        Path(a.out).write_text(out)
        print(f'{len(tab)} handler entries -> {a.out}' + (f' ({dup} aliased labels)' if dup else ''))
    else:
        print(out)


if __name__ == '__main__':
    main()

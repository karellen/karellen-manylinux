#!/usr/bin/env python3

import sys

with open(sys.argv[1], "rt") as f:
    lines = list(l.rstrip() for l in f.readlines())

new_lines = []

for idx, line in enumerate(lines):
    if line.startswith("RUN manylinux-entrypoint /build_scripts/build-cpython.sh"):
        cpython_build_block = [line, ""]
        cpython_build_block.extend(lines[idx-2:idx+1])
        cpython_build_block[2] += "_shared"
        cpython_build_block[-1] += " shared"

        new_lines.extend(cpython_build_block)
    elif "--mount=type=bind,target=/build_cpython" in line:
        new_lines.append(line)
        if line.startswith("RUN"):
            line = "    " + line[4:]
        part1, part2 = line.split(",from=")
        new_lines.append(part1 + "_shared" + ",from=" + part2.replace(" \\", "_shared \\"))
    else:
        new_lines.append(line)

with open(sys.argv[1], "wt") as f:
    f.write("\n".join(new_lines))

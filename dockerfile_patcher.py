#!/usr/bin/env python3

import sys

with open(sys.argv[1], "rt") as f:
    lines = list(l.rstrip() for l in f.readlines())

new_lines = []
no_img_defs_patched = True
no_img_refs_patched = True
ignore_lines = 0
for idx, line in enumerate(lines):
    if ignore_lines:
        ignore_lines -= 1
        continue
    if line.startswith("FROM build_cpython AS build_cpython"):
        cpython_build_block = lines[idx:idx+4] + [""]
        cpython_build_block.extend(lines[idx:idx+4])
        cpython_build_block[5] += "_shared"
        cpython_build_block[-1] += " shared"
        new_lines.extend(cpython_build_block)
        ignore_lines = 3
        no_img_defs_patched = False
    elif "--mount=type=bind,target=/build_cpython" in line:
        new_lines.append(line)
        if line.startswith("RUN"):
            line = "    " + line[4:]
        part1, part2 = line.split(",from=")
        new_lines.append(part1 + "_shared" + ",from=" + part2.replace(" \\", "_shared \\"))
        no_img_refs_patched = False
    else:
        new_lines.append(line)

if no_img_defs_patched or no_img_refs_patched:
    print("Failed patching Dockerfile!", file=sys.stderr)
    sys.exit(1)

with open(sys.argv[1], "wt") as f:
    f.write("\n".join(new_lines))

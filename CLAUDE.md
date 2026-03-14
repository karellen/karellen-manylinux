# karellen-manylinux

A fork of [pypa/manylinux](https://github.com/pypa/manylinux) that builds custom
manylinux Docker images with Karellen-specific modifications (shared Python builds,
GHCR deployment instead of Quay.io, reduced platform matrix).

## Repository Structure

- `manylinux/` — git submodule tracking `pypa/manylinux` `main` branch
- `build.yml.patch` — patch applied to the upstream `.github/workflows/build.yml`
  to produce the Karellen CI workflow
- `patches/0-patch.patch` — patch applied to the manylinux submodule source
  (build scripts, deploy, Dockerfile references, tests)
- `dockerfile_patcher.py` — Python script that patches the manylinux Dockerfile
  to add shared CPython build variants
- `patch_build_yml.sh` — copies upstream `build.yml` and applies `build.yml.patch`
- `patch.sh` — restores the submodule, applies `patches/*.patch`, then runs
  `dockerfile_patcher.py`
- `build.sh` — local build script (runs `patch.sh` then builds a single image)

## Patching System

The project maintains two independent patch files that must stay in sync with the
upstream `pypa/manylinux` repository:

### `build.yml.patch`

Applied by `patch_build_yml.sh` at CI update time. Key transformations:
- Branch references: `main` → `master`
- Repository references: `pypa/manylinux` → `karellen/karellen-manylinux`
- Registry: `quay.io` → `ghcr.io`
- Environment output: `'quay.io'` → `'ghcr.io'`
- Deploy credentials: `QUAY_USERNAME`/`QUAY_PASSWORD` → `GITHUB_TOKEN`
- Removes `pre-commit` action step
- Removes extra platforms from build matrix (armv7l, ppc64le, riscv64, s390x)
- Adds `submodules: true`, Patch step, Start Docker step to the build job
- Build/Deploy steps `cd manylinux` before running scripts

### `patches/0-patch.patch`

Applied by `patch.sh` to the manylinux submodule. Key transformations:
- Image registry: `quay.io/pypa/` → `ghcr.io/karellen/`
- Deploy login: quay.io → ghcr.io with `$GITHUB_TOKEN`
- Adds shared CPython build support (build-cpython.sh, finalize-one.sh,
  manylinux-interpreters.py, run_tests.sh)
- Adds `patchelf` to runtime packages
- Adds `epel-release` to manylinux2014 repos

## Fixing Patch Failures

When the upstream changes and a patch hunk fails:

1. Check the CI log to identify which hunk failed
2. Compare the patch's expected context/removed lines against the current upstream file
3. **Maintain equivalent behavior** — if upstream refactors a condition (e.g., moves
   a check from inline to a job output), follow the same pattern with Karellen values
   rather than hardcoding the old approach
4. Regenerate the patch cleanly:
   - Copy the current upstream file
   - Apply all Karellen transformations manually
   - `diff -u original modified` to produce the new patch
5. Verify with `patch_build_yml.sh` (for build.yml) or `patch --dry-run` (for
   submodule patches)

## CI Workflows

- `update.yml` — runs hourly, checks if upstream submodule has new commits,
  updates the submodule, applies `patch_build_yml.sh`, commits and pushes
- `build.yml` — the patched upstream workflow that builds Docker images for
  x86_64, aarch64, and i686 platforms and deploys to GHCR

## Key Differences from Upstream

- Only builds x86_64, aarch64, i686 (upstream also builds armv7l, ppc64le,
  riscv64, s390x)
- Deploys to GitHub Container Registry (ghcr.io) instead of Quay.io
- Includes shared CPython builds alongside static builds
- Uses `master` branch instead of `main`

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
- `patch_build_yml.sh` — copies upstream `build.yml`, applies the guarded `sed`
  transformations, then applies `build.yml.patch`
- `patch.sh` — restores the submodule, applies `patches/*.patch`, then runs
  `dockerfile_patcher.py`
- `build.sh` — local build script (runs `patch.sh` then builds a single image)

## Patching System

The project maintains two independent patch files that must stay in sync with the
upstream `pypa/manylinux` repository:

### `patch_build_yml.sh` — the `sed` stage

Transformations whose patch context would contain a pinned action SHA live here
rather than in `build.yml.patch`. Upstream bumps those SHAs on roughly every
dependency update, and each bump used to break a hunk (`c18235e`, `c8c7d8b`,
`e1a4781`). `sed` is blind to the SHAs, so these survive dependency bumps:
- Removes the `pre-commit` action step (context: the `actions/setup-python` SHA)
- Branch references: `refs/heads/main` → `refs/heads/master` (context: the
  `docker/login-action` SHA)
- Repository references: `pypa/manylinux` → `karellen/karellen-manylinux`
- Environment output: `'quay.io'` → `'ghcr.io'`, on the `build_matrix` output
  only — `deploy_multiarch` keeps comparing against `'quay.io'` so that it stays
  disabled, since `deploy_multiarch.sh` is not patched for ghcr.io
- Reduces the build matrix to x86_64, aarch64 and i686, as an **allow-list**, so
  a platform added upstream is dropped automatically instead of breaking the
  update (`682a9c6`) or silently entering the matrix

Because `sed` silently does nothing when its pattern stops matching, every
substitution is guarded by an `expect <count> <regex>` assertion. If upstream
refactors one of these lines the update fails loudly instead of publishing a
workflow that still points at `pypa`/`quay.io`. **Any new substitution must come
with its own assertion.**

### `build.yml.patch`

Applied by `patch_build_yml.sh` after the `sed` stage. Restricted to structural
changes whose context is free of pinned action SHAs:
- Trigger block: `branches: [master]` for push and pull_request, `paths` filters
  dropped
- Adds `submodules: true`, Patch step, Start Docker step to the build job
- Build/Deploy steps `cd manylinux` before running scripts
- Deploy step: condition `== 'ghcr.io'`, and `QUAY_USERNAME`/`QUAY_PASSWORD` →
  `GITHUB_TOKEN`

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
   - Copy the current upstream file and run the `sed` stage over it — that copy,
     not the raw upstream file, is what `build.yml.patch` applies to
   - Apply the structural Karellen transformations manually
   - `diff -u sed_stage_output modified` to produce the new patch
5. Verify with `patch_build_yml.sh` (for build.yml) or `patch --dry-run` (for
   submodule patches)

**Do not put a line containing a pinned action SHA into `build.yml.patch`**, as
context or as a changed line. Upstream bumps those constantly and each bump then
breaks the update. If a needed edit sits next to one, express it as a guarded
`sed` in `patch_build_yml.sh` instead.

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

#!/bin/bash -eEu

SRC="manylinux/.github/workflows/build.yml"
DST=".github/workflows/build.yml"

cp "$SRC" "$DST"

# Assert that a regex matches an exact number of lines in $DST. sed silently
# does nothing when its pattern stops matching, so every substitution below is
# guarded: an upstream refactoring fails the update loudly instead of quietly
# producing a workflow that still points at pypa/quay.io.
expect() {
  local expected="$1" regex="$2" actual
  actual="$(grep -c -E -- "$regex" "$DST" || true)"
  if [ "$actual" != "$expected" ]; then
    echo "$0: expected $expected line(s) matching /$regex/ in $DST, found $actual" >&2
    exit 1
  fi
}

# The edits below are done here rather than in build.yml.patch because their
# patch context would contain pinned action SHAs, which upstream bumps on
# roughly every dependency update and which broke a hunk every time.

# Drop the pre-commit step (patch context: the actions/setup-python SHA).
expect 1 '^ +- uses: pre-commit/action@'
sed -i -E '/^ +- uses: pre-commit\/action@/d' "$DST"

# Branch and repository references (patch context: the docker/login-action SHA).
expect 2 "github\.ref == 'refs/heads/main'"
sed -i "s|github.ref == 'refs/heads/main'|github.ref == 'refs/heads/master'|g" "$DST"

expect 2 "github\.repository == 'pypa/manylinux'"
sed -i "s|github.repository == 'pypa/manylinux'|github.repository == 'karellen/karellen-manylinux'|g" "$DST"

# Deployment environment name. Only the build_matrix output is renamed: the
# deploy_multiarch job keeps comparing against 'quay.io' so that it stays
# disabled here (its deploy_multiarch.sh is not patched for ghcr.io).
expect 1 "^      environment: .*'quay.io'"
sed -i -E "/^      environment: .*'quay.io'/ s|'quay.io'|'ghcr.io'|" "$DST"

# Keep only the platforms this fork builds. Expressed as an allow-list, with no
# assertion on the incoming platform count, so that a platform added upstream is
# excluded automatically instead of failing the update. The result is asserted
# instead: if upstream restructures the matrix, the surviving entries stop
# matching and the update fails rather than building the wrong platform set.
sed -i -E '/^ +#? *\("(x86_64|aarch64|i686)", /!{/^ +#? *\("[a-z0-9_]+", "[a-z0-9.-]+", \(/d}' "$DST"
expect 1 '^ +\("x86_64", '
expect 1 '^ +\("aarch64", '
expect 1 '^ +\("i686", '
expect 3 '^ +#? *\("[a-z0-9_]+", "[a-z0-9.-]+", \('

patch -p1 < build.yml.patch

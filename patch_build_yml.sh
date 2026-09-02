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

# Drop the upstream lint job. It runs upstream's linter against this fork's
# root checkout, which has no lint configuration of its own. The whole job goes
# rather than the individual tool step, so that upstream swapping linters
# (pre-commit -> prek in #1988) does not break the update; and it is done here
# rather than in build.yml.patch because the step's context is a pinned SHA.
expect 1 '^  pre_commit:$'
expect 1 '^    needs: pre_commit$'
sed -i -E '/^  pre_commit:$/,/^  [a-z_][a-z0-9_]*:$/{/^  [a-z_][a-z0-9_]*:$/!d}; /^  pre_commit:$/d' "$DST"
sed -i -E '/^    needs: pre_commit$/d' "$DST"
expect 0 'pre_commit'
expect 1 '^  build_matrix:$'

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

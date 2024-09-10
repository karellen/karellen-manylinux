#!/bin/bash -eEu

pushd manylinux
git restore .github/workflows/build.yml
popd

cp manylinux/.github/workflows/build.yml .github/workflows/build.yml
patch -p1 < build.yml.patch


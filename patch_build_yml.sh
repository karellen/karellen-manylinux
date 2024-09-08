#!/bin/bash -eEu

cp manylinux/.github/workflows/build.yml .github/workflows/build.yml
patch -p1 < build.yml.patch


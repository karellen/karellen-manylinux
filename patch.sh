#!/bin/bash -eEu

pushd manylinux
git restore \*
popd

for f in patches/*; do
  patch -d manylinux -p1 < $f
done

./dockerfile_patcher.py manylinux/docker/Dockerfile



#!/bin/bash -eEu

./patch.sh

pushd manylinux
MANYLINUX_BUILD_FRONTEND=docker PLATFORM=x86_64 POLICY=manylinux_2_28 COMMIT_SHA=$(git rev-parse HEAD) ./build.sh


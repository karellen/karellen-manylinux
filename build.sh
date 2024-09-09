#!/bin/bash -eEu

./patch.sh

COMMIT_SHA=$(git rev-parse HEAD:manylinux)
pushd manylinux
MANYLINUX_BUILD_FRONTEND=docker PLATFORM=i686 POLICY=manylinux2014 COMMIT_SHA=$COMMIT_SHA ./build.sh

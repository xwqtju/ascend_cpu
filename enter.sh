#!/usr/bin/env bash
set -euo pipefail

CHIP="${CHIP:-910b}"
CANN_VERSION="${CANN_VERSION:-8.5.0}"
IMAGE_NAME="${IMAGE_NAME:-ascend-cpu-debug:${CANN_VERSION}-${CHIP}}"
WORKSPACE="${WORKSPACE:-/Users/xuwenqiang/Desktop/workspace}"

docker run --rm -it \
  --name ascend-cpu-debug \
  --platform linux/arm64 \
  --shm-size=4g \
  -v "${WORKSPACE}:/workspace" \
  -w /workspace \
  "${IMAGE_NAME}" \
  /bin/bash -l

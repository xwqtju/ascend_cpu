#!/usr/bin/env bash
set -euo pipefail

CHIP="${CHIP:-910b}"
CANN_VERSION="${CANN_VERSION:-8.5.0}"
IMAGE_NAME="${IMAGE_NAME:-ascend-cpu-debug:${CANN_VERSION}-${CHIP}}"

docker build \
  --build-arg CHIP="${CHIP}" \
  --build-arg CANN_VERSION="${CANN_VERSION}" \
  -t "${IMAGE_NAME}" \
  "$(cd "$(dirname "$0")" && pwd)"

echo "Built ${IMAGE_NAME}"

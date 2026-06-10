#!/usr/bin/env bash
# =============================================================================
# 进入 CANN 仿真容器
# 用法: IMAGE_NAME=ascend-cpu-debug:9.0.0-910b bash enter.sh
# =============================================================================
set -euo pipefail

CHIP="${CHIP:-910b}"
CANN_VERSION="${CANN_VERSION:-8.5.0}"
IMAGE_NAME="${IMAGE_NAME:-ascend-cpu-debug:${CANN_VERSION}-${CHIP}}"
# 自动检测 workspace：脚本所在目录的上级
WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"

PLATFORM_FLAG=""
if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
    PLATFORM_FLAG="--platform linux/arm64"
fi

echo "镜像: ${IMAGE_NAME}"
echo "工作区: ${WORKSPACE} -> /workspace"

docker run --rm -it \
  --name ascend-cpu-debug \
  ${PLATFORM_FLAG} \
  --shm-size=8g \
  -v "${WORKSPACE}:/workspace" \
  -w /workspace/ascend_cpu \
  "${IMAGE_NAME}" \
  /bin/bash -l

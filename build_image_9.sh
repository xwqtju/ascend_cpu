#!/usr/bin/env bash
# =============================================================================
# 构建 CANN 9.0.0 开发镜像
# =============================================================================
set -euo pipefail

# 镜像选择
#   国内用户推荐 DaoCloud 镜像: m.daocloud.io/quay.io/ascend/cann:9.0.0-910b-ubuntu22.04-py3.11
#   海外用户用 Docker Hub:    ascendai/cann:9.0.0-910-ubuntu22.04-py3.11
BASE_IMAGE="${BASE_IMAGE:-ascendai/cann:9.0.0-910-ubuntu22.04-py3.11}"
IMAGE_NAME="${IMAGE_NAME:-ascend-cpu-debug:9.0.0-910b}"

echo "基础镜像: ${BASE_IMAGE}"
echo "目标镜像: ${IMAGE_NAME}"
echo ""

# 拉取基础镜像
docker pull "${BASE_IMAGE}"

# 构建开发镜像
docker build \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  -f "$(dirname "$0")/Dockerfile.cann9" \
  -t "${IMAGE_NAME}" \
  "$(dirname "$0")"

echo ""
echo "构建完成: ${IMAGE_NAME}"
echo ""
echo "进入容器: IMAGE_NAME=${IMAGE_NAME} bash enter.sh"

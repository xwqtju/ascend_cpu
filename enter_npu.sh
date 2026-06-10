#!/usr/bin/env bash
# =============================================================================
# NPU 上板实测入口
# 用法: bash enter_npu.sh [chip_version]
# 示例: bash enter_npu.sh Ascend910B2
# =============================================================================
set -euo pipefail

CHIP="${1:-910b}"
SOC_VERSION="${2:-Ascend910B2}"
CANN_VERSION="${CANN_VERSION:-9.0.0}"
IMAGE_NAME="${IMAGE_NAME:-ascend-cpu-debug:${CANN_VERSION}-${CHIP}}"
WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")"/.. && pwd)}"

echo "=== NPU 上板实测 ==="
echo "Chip: ${CHIP}, SOC: ${SOC_VERSION}"
echo ""

# NPU 设备检查
if [ ! -e /dev/davinci0 ]; then
    echo "错误: 未检测到 NPU 设备 /dev/davinci0"
    echo "请确认: 1) Ascend 驱动已安装  2) npu-smi 可见设备"
    exit 1
fi

# 检查驱动版本
npu-smi info 2>/dev/null | head -10 || echo "警告: npu-smi 不可用"

docker run --rm -it \
  --name ascend-cpu-debug-npu \
  --shm-size=32g \
  --privileged \
  --device=/dev/davinci0 \
  --device=/dev/davinci1 \
  --device=/dev/davinci2 \
  --device=/dev/davinci3 \
  --device=/dev/davinci4 \
  --device=/dev/davinci5 \
  --device=/dev/davinci6 \
  --device=/dev/davinci7 \
  --device=/dev/davinci_manager \
  --device=/dev/devmm_svm \
  --device=/dev/hisi_hdc \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/dcmi:/usr/local/dcmi \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  -v /etc/ascend_install.info:/etc/ascend_install.info \
  -v "${WORKSPACE}:/workspace" \
  -w /workspace/ascend_cpu \
  -e SOC_VERSION="${SOC_VERSION}" \
  "${IMAGE_NAME}" \
  /bin/bash -l

#!/usr/bin/env bash
# =============================================================================
# Ascend CANN CPU 仿真环境 — 一键安装脚本
# 支持: Mac (Colima) / Linux 服务器 / NPU 上板
# 用法: bash setup.sh [8.5.0|9.0.0] [sim|npu]
# =============================================================================
set -euo pipefail

CANN_VERSION="${1:-9.0.0}"
MODE="${2:-sim}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Ascend CANN 环境安装${NC}"
echo -e "${CYAN}  版本: ${CANN_VERSION}  模式: ${MODE}${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ============================================================
# 1. 检测环境
# ============================================================
info "检测系统环境..."

ARCH=$(uname -m)
OS=$(uname -s)

case "$ARCH" in
    arm64|aarch64) PLATFORM="arm64" ;;
    x86_64)        PLATFORM="x86_64" ;;
    *)             err "不支持的架构: $ARCH" ;;
esac

case "$OS" in
    Darwin)
        OS_TYPE="mac"
        # Mac 需要 Colima
        if ! command -v colima &>/dev/null && ! docker info &>/dev/null 2>&1; then
            err "Mac 需要 Docker 运行时。请安装 Colima: brew install colima && colima start --memory 16 --cpu 8"
        fi
        ;;
    Linux)
        OS_TYPE="linux"
        if ! command -v docker &>/dev/null; then
            err "请先安装 Docker: curl -fsSL https://get.docker.com | bash"
        fi
        ;;
    *)      err "不支持的系统: $OS" ;;
esac
ok "系统: $OS ($OS_TYPE), 架构: $ARCH ($PLATFORM)"

# ============================================================
# 2. 确定镜像和 Dockerfile
# ============================================================
case "$CANN_VERSION" in
    8.5.0|8.5)
        IMAGE_NAME="ascend-cpu-debug:8.5.0-910b"
        case "$PLATFORM" in
            arm64)  DOCKERFILE="Dockerfile" ;;
            x86_64) DOCKERFILE="Dockerfile.x86_64" ;;
        esac
        ;;
    9.0.0|9.0)
        IMAGE_NAME="ascend-cpu-debug:9.0.0-910b"
        DOCKERFILE="Dockerfile.cann9"
        # 9.0.0 优先用 DaoCloud 镜像（国内快）
        if [ "$PLATFORM" = "arm64" ]; then
            BASE_IMAGE="m.daocloud.io/quay.io/ascend/cann:9.0.0-910b-ubuntu22.04-py3.11"
        else
            BASE_IMAGE="ascendai/cann:9.0.0-910-ubuntu22.04-py3.11"
        fi
        ;;
    *)  err "不支持的 CANN 版本: $CANN_VERSION (可选 8.5.0, 9.0.0)" ;;
esac

info "镜像: $IMAGE_NAME, Dockerfile: $DOCKERFILE"

# ============================================================
# 3. 构建/拉取镜像
# ============================================================
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    ok "镜像已存在: $IMAGE_NAME"
else
    info "构建镜像（5-30 分钟，取决于网络）..."
    cd "$REPO_DIR"
    if [ "$CANN_VERSION" = "9.0.0" ] || [ "$CANN_VERSION" = "9.0" ]; then
        BASE_IMAGE="${BASE_IMAGE}" IMAGE_NAME="${IMAGE_NAME}" bash build_image_9.sh
    else
        IMAGE_NAME="${IMAGE_NAME}" bash build_image.sh
    fi
    ok "镜像构建完成: $IMAGE_NAME"
fi

# ============================================================
# 4. 验证环境
# ============================================================
info "验证 CANN 环境..."
DOCKER_PLATFORM=""
[ "$PLATFORM" = "arm64" ] && [ "$OS_TYPE" = "mac" ] && DOCKER_PLATFORM="--platform linux/arm64"

docker run --rm $DOCKER_PLATFORM \
    -v "${REPO_DIR}:/workspace" \
    -w /workspace \
    "${IMAGE_NAME}" \
    bash check_env.sh 2>&1 | head -5

ok "CANN 环境正常"

# ============================================================
# 5. 输出使用说明
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$MODE" = "npu" ]; then
    echo "NPU 上板模式:"
    echo "  cd ${REPO_DIR}"
    echo "  bash enter_npu.sh"
    echo ""
    echo "容器内编译运行:"
    echo "  cd /workspace/custom_ops/aclnn_matmul"
    echo "  bash gen_data.py"
    echo "  ./aclnn_matmul"
else
    echo "进入仿真容器:"
    echo "  cd ${REPO_DIR}"
    echo "  IMAGE_NAME=${IMAGE_NAME} bash enter.sh"
    echo ""
    echo "容器内运行算子:"
    echo "  bash run_operator.sh matmul    # AscendC kernel"
    echo "  cd custom_ops/aclnn_matmul     # ACLNN 直调"
    echo "  python3 gen_data.py && LD_PRELOAD=\"...\" ./aclnn_matmul"
    echo ""
    echo "切换到 NPU 上板:"
    echo "  bash setup.sh ${CANN_VERSION} npu"
fi

echo ""
echo "项目地址: https://github.com/xwqtju/ascend_cpu"

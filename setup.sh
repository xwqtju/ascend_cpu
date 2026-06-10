#!/usr/bin/env bash
# =============================================================================
# Ascend CANN 仿真环境 — 一键安装脚本
# 支持: Mac (Apple Silicon) / Ubuntu 24.04 / Ubuntu 22.04 / 其他 Linux
#
# 用法:
#   bash setup.sh                  # 默认 CANN 9.0.0 + 仿真模式
#   bash setup.sh 9.0.0 sim        # CANN 9.0.0 + 仿真
#   bash setup.sh 9.0.0 npu        # CANN 9.0.0 + NPU 上板
#   bash setup.sh 8.5.0 sim        # CANN 8.5.0 + 仿真
# =============================================================================
set -euo pipefail

CANN_VERSION="${1:-9.0.0}"
MODE="${2:-sim}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Ascend CANN 算子仿真环境 — 一键安装${NC}"
echo -e "${CYAN}  CANN ${CANN_VERSION} | 模式: ${MODE}${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ============================================================
# 1. 检测系统环境
# ============================================================
info "检测系统环境..."

ARCH=$(uname -m)
OS=$(uname -s)

case "$ARCH" in
    arm64|aarch64) PLATFORM="arm64" ;;
    x86_64|amd64)  PLATFORM="x86_64" ;;
    *)             err "不支持的 CPU 架构: $ARCH" ;;
esac

OS_TYPE=""
DISTRO=""

case "$OS" in
    Darwin)
        OS_TYPE="mac"
        info "macOS + $(sw_vers -productName 2>/dev/null || echo Mac)"
        if ! command -v docker &>/dev/null; then
            err "请先安装 Docker。Mac 推荐 Colima:\n  brew install colima docker\n  colima start --memory 16 --cpu 8"
        fi
        ;;
    Linux)
        OS_TYPE="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO="$NAME $VERSION_ID"
            info "Linux 发行版: $DISTRO"
        fi
        if ! command -v docker &>/dev/null; then
            echo ""
            warn "Docker 未安装。请执行:"
            echo ""
            if echo "$DISTRO" | grep -qi "ubuntu"; then
                echo "  # Ubuntu (22.04 / 24.04 通用)"
                echo "  sudo apt update"
                echo "  sudo apt install -y docker.io"
                echo "  sudo usermod -aG docker \$USER"
                echo "  # 退出重新登录使权限生效"
            else
                echo "  curl -fsSL https://get.docker.com | sudo bash"
                echo "  sudo usermod -aG docker \$USER"
            fi
            echo ""
            err "安装 Docker 后重新运行本脚本"
        fi
        ;;
    *)  err "不支持的操作系统: $OS" ;;
esac

ok "系统: $OS ($OS_TYPE) | CPU: $ARCH ($PLATFORM)"

# 检查 Docker 是否可用
if ! docker info &>/dev/null 2>&1; then
    warn "Docker 已安装但未运行。请启动 Docker 服务后重试"
    if [ "$OS_TYPE" = "linux" ]; then
        echo "  sudo systemctl start docker"
    else
        echo "  colima start --memory 16 --cpu 8"
    fi
    exit 1
fi

# 建议内存（仅提示）
if [ "$OS_TYPE" = "mac" ]; then
    MEM=$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3}' || echo "unknown")
    info "Docker 可用内存: $MEM"
    if [ "$MEM" != "unknown" ] && [ "${MEM%GiB}" -lt 12 ]; then
        warn "内存不足 12GB，大算子仿真可能失败。建议 colima start --memory 16"
    fi
fi

# ============================================================
# 2. 确定镜像和 Dockerfile
# ============================================================
case "$CANN_VERSION" in
    8.5.0|8.5)
        IMAGE_NAME="ascend-cpu-debug:8.5.0-910b"
        if [ "$PLATFORM" = "arm64" ]; then
            DOCKERFILE="Dockerfile"
        else
            DOCKERFILE="Dockerfile.x86_64"
        fi
        ;;
    9.0.0|9.0)
        IMAGE_NAME="ascend-cpu-debug:9.0.0-910b"
        DOCKERFILE="Dockerfile.cann9"
        # ARM64 用 DaoCloud 镜像（国内快），x86_64 用 Docker Hub
        if [ "$PLATFORM" = "arm64" ]; then
            BASE_IMAGE="m.daocloud.io/quay.io/ascend/cann:9.0.0-910b-ubuntu22.04-py3.11"
        else
            BASE_IMAGE="ascendai/cann:9.0.0-910-ubuntu22.04-py3.11"
        fi
        ;;
    *)  err "不支持的 CANN 版本: $CANN_VERSION。可选: 8.5.0, 9.0.0" ;;
esac

info "目标镜像: $IMAGE_NAME"
info "Dockerfile: $DOCKERFILE"

# ============================================================
# 3. 构建 / 拉取镜像
# ============================================================
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    ok "镜像已存在: $IMAGE_NAME"
else
    info "开始构建镜像（首次约 10-30 分钟，取决于网络带宽）..."
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
# Mac ARM64 需要 --platform，Linux 不需要
DOCKER_PLATFORM=""
[ "$PLATFORM" = "arm64" ] && [ "$OS_TYPE" = "mac" ] && DOCKER_PLATFORM="--platform linux/arm64"

docker run --rm $DOCKER_PLATFORM \
    -v "${REPO_DIR}:/workspace" \
    -w /workspace \
    "${IMAGE_NAME}" \
    bash check_env.sh 2>&1 | head -5

ok "CANN 环境验证通过"

# ============================================================
# 5. 输出使用说明
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$MODE" = "npu" ]; then
    echo "进 NPU 容器:"
    echo "  cd ${REPO_DIR} && bash enter_npu.sh"
else
    echo "进仿真容器:"
    echo "  cd ${REPO_DIR} && bash enter.sh"
    echo ""
    echo "容器内试试这些:"
    echo "  # ACLNN 直调 MatMul（最简单）"
    echo "  cd /workspace/ascend_cpu/custom_ops/aclnn_matmul"
    echo "  python3 gen_data.py"
    echo "  LD_PRELOAD=\"libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so\" ./aclnn_matmul"
    echo ""
    echo "  # AscendC kernel 示例"
    echo "  bash /workspace/ascend_cpu/run_operator.sh matmul reduce sub"
    echo ""
    echo "  # 查看 CANN 内部算子库"
    echo "  ls /usr/local/Ascend/cann-9.0.0/aarch64-linux/include/aclnnop/"
    echo ""
    echo "切 NPU 上板:"
    echo "  bash setup.sh ${CANN_VERSION} npu"
fi

echo ""
echo "仓库: https://github.com/xwqtju/ascend_cpu"

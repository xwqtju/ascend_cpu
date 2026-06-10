#!/usr/bin/env bash
# =============================================================================
# CANN 8.5.0 CPU 仿真算子运行脚本
# 用法: 在容器内执行  bash run_operator.sh [算子名]
# 或:   docker run ... bash run_operator.sh [算子名]
# =============================================================================
set -euo pipefail

source /etc/profile.d/ascend.sh 2>/dev/null || true

# === 环境配置 ===
SIM_DIR="${ASCEND_HOME_PATH:-/usr/local/Ascend/cann-8.5.0}/tools/simulator/Ascend910B1/lib"
ASCEND_LIB="${ASCEND_HOME_PATH:-/usr/local/Ascend/cann-8.5.0}/lib64"
DEV_LIB="${ASCEND_HOME_PATH:-/usr/local/Ascend/cann-8.5.0}/devlib/aarch64"
TIK_LIB="${ASCEND_HOME_PATH:-/usr/local/Ascend/cann-8.5.0}/tools/tikicpulib/lib"
TIK_LIB_V="${ASCEND_HOME_PATH:-/usr/local/Ascend/cann-8.5.0}/tools/tikicpulib/lib/Ascend910B1"

export LD_LIBRARY_PATH="${SIM_DIR}:${ASCEND_LIB}:${DEV_LIB}:${TIK_LIB}:${TIK_LIB_V}:${LD_LIBRARY_PATH:-}"
PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so"

SDK_BASE="/workspace/ascend_cpu_debug/asc-devkit-8.5.0/examples"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# === 算子目录 ===
declare -A OPS=(
    ["add"]="00_introduction/01_add/basic_api_tque_add,add"
    ["matmul"]="00_introduction/02_matmul/normal_matmul,demo"
    ["matmulleakyrelu"]="00_introduction/03_matmulleakyrelu,demo"
    ["addn"]="00_introduction/04_addn,demo"
    ["broadcast"]="00_introduction/05_broadcast,demo"
    ["reduce"]="00_introduction/06_reduce,demo"
    ["sub"]="00_introduction/07_sub,demo"
    ["helloworld"]="00_introduction/00_helloworld,demo"
    ["unaligned_abs"]="00_introduction/08_unaligned_abs,demo"
    ["unaligned_reducemin"]="00_introduction/09_unaligned_reducemin,demo"
    ["unaligned_wholereducesum"]="00_introduction/10_unaligned_wholereducesum,demo"
    ["vectoradd"]="00_introduction/11_vectoradd,demo"
    ["printf"]="01_utilities/00_printf,demo"
    ["assert"]="01_utilities/01_assert,demo"
    ["dumptensor"]="01_utilities/02_dumptensor,cube"
    ["cpudebug"]="01_utilities/03_cpudebug,add"
    ["addcdiv"]="03_libraries/00_addcdivcustom,demo"
    ["scatter"]="03_libraries/01_scattercustom,demo"
    ["group_matmul"]="04_best_practices/00_group_matmul,demo"
    ["aicpu_tiling"]="04_best_practices/01_aicpu_device_tiling,demo"
)

run_op() {
    local name="$1"
    local info="${OPS[$name]:-}"
    if [ -z "$info" ]; then
        echo "未知算子: $name"
        echo "可用: ${!OPS[*]}"
        return 1
    fi

    IFS=',' read -r subpath binary <<< "$info"
    local op_dir="${SDK_BASE}/${subpath}"

    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  算子: ${GREEN}${name}${NC}"
    echo -e "${CYAN}  路径: ${subpath}${NC}"
    echo -e "${CYAN}========================================${NC}"

    cd "$op_dir"
    rm -rf build-cpu

    echo -e "${YELLOW}[1/3] 编译...${NC}"
    cmake -B build-cpu -DCMAKE_ASC_RUN_MODE=cpu > /dev/null 2>&1
    cmake --build build-cpu -j > /dev/null 2>&1
    echo "  -> 编译完成"

    echo -e "${YELLOW}[2/3] 准备数据...${NC}"
    cd build-cpu
    mkdir -p input output
    if [ -f ../scripts/gen_data.py ]; then
        python3 ../scripts/gen_data.py > /dev/null 2>&1 || true
        echo "  -> 测试数据已生成"
    fi

    echo -e "${YELLOW}[3/3] 仿真运行...${NC}"
    echo ""
    env LD_PRELOAD="${PRELOAD}" timeout 120 "./${binary}" 2>&1
    local rc=$?
    echo ""
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}  [OK] ${name} 运行成功${NC}"
    else
        echo -e "  [EXIT: $rc] ${name}"
    fi
    echo ""
}

# === 主程序 ===
if [ $# -eq 0 ]; then
    echo "用法: bash run_operator.sh <算子名> [算子名...]"
    echo ""
    echo "可用算子:"
    for op in $(echo "${!OPS[@]}" | tr ' ' '\n' | sort); do
        echo "  - $op"
    done
    echo ""
    echo "示例: bash run_operator.sh matmul"
    echo "      bash run_operator.sh matmul reduce sub"
    exit 0
fi

for op_name in "$@"; do
    run_op "$op_name" || true
done

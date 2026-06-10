#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ascend-cpu-debug:8.5.0-910b}"
WORKSPACE="${WORKSPACE:-/Users/xuwenqiang/Desktop/workspace}"
SAMPLE_DIR="/workspace/ascend_cpu_debug/asc-devkit-8.5.0/examples/01_utilities/03_cpudebug"

docker run --rm \
  --platform linux/arm64 \
  -v "${WORKSPACE}:/workspace" \
  -w "${SAMPLE_DIR}" \
  "${IMAGE_NAME}" \
  bash -lc '
    set -euo pipefail

    export ASCEND_INSTALL_PATH=/usr/local/Ascend/cann-8.5.0
    export SOC_VERSION=Ascend910B1
    source /usr/local/Ascend/cann-8.5.0/bin/setenv.bash

    export DEVLIB=/usr/local/Ascend/cann-8.5.0/aarch64-linux/devlib
    export LD_LIBRARY_PATH=${DEVLIB}:/usr/local/Ascend/cann-8.5.0/tools/tikicpulib/lib:/usr/local/Ascend/cann-8.5.0/tools/tikicpulib/lib/Ascend910B1:/usr/local/Ascend/cann-8.5.0/tools/simulator/Ascend910B1/lib:/usr/local/Ascend/cann-8.5.0/lib64:${LD_LIBRARY_PATH:-}
    export LIBRARY_PATH=${DEVLIB}:${LIBRARY_PATH:-}

    rm -rf build out add input_x.bin input_y.bin output_z.bin golden.bin npuchk

    cmake -B build -DCMAKE_INSTALL_PREFIX=./ -DSOC_VERSION=Ascend910B1
    cmake --build build -j
    cmake --install build
    cp ./build/add ./

    python3 scripts/gen_data.py
    export LD_LIBRARY_PATH=$(pwd)/out/lib:$(pwd)/out/lib64:${LD_LIBRARY_PATH}
    ./add
    python3 scripts/verify_result.py output_z.bin golden.bin

    echo
    echo "npu check logs:"
    find npuchk -maxdepth 2 -type f 2>/dev/null | sort || true
  '

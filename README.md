# Ascend C CANN 算子 CPU 仿真环境

在 Mac (Apple Silicon) / Linux 服务器上通过 Docker 容器运行 CANN 算子，使用 CPU 仿真器模拟 Ascend AI Core，无需真实 NPU 硬件。

**支持 CANN 8.5.0 / 9.0.0 双版本。**

## 架构

```
Mac / Linux 服务器
  └── Docker 容器 (ubuntu:22.04)
       ├── CANN Toolkit (8.5.0 或 9.0.0)
       ├── AscendC 编译器 (bisheng)
       ├── CPU 仿真器 (PEM DaVinci Model)
       │     ├── libpem_davinci.so       周期精确仿真引擎
       │     ├── libruntime_cmodel.so    运行时仿真层
       │     └── libnpu_drv.so           NPU 驱动仿真
       └── tikicpulib                    CPU 调试库
```

**仿真原理**：`LD_PRELOAD` 注入仿真库，替换真实的 NPU 驱动/HAL 层，算子二进制在 CPU 上周期精确执行。

---

## 快速开始

### 前置条件

- macOS Apple Silicon 或 Linux (x86_64/ARM64)
- Docker 运行时就绪（Mac 用 Colima，Linux 原生 Docker）
- Docker 镜像已构建

### 构建镜像

```bash
# CANN 8.5.0
bash build_image.sh

# CANN 9.0.0
bash build_image_9.sh
```

### 进入容器

```bash
# 8.5.0
IMAGE_NAME=ascend-cpu-debug:8.5.0-910b bash enter.sh

# 9.0.0
IMAGE_NAME=ascend-cpu-debug:9.0.0-910b bash enter.sh
```

### 运行算子

```bash
# 容器内
bash run_operator.sh matmul           # 单个算子
bash run_operator.sh add sub reduce   # 批量
```

---

## CANN 8.5.0 vs 9.0.0

| | 8.5.0 | 9.0.0 |
|------|------|------|
| 镜像大小 | 12.8GB | 16.1GB |
| 构建方式 | 从 .run 包安装 | 基于官方 Docker 镜像 |
| cmake 编译 | `-DCMAKE_ASC_RUN_MODE=cpu` | `-DCMAKE_ASC_ARCHITECTURES=dav-2201` |
| 仿真运行 | `LD_PRELOAD=... ./demo` | `LD_PRELOAD=... ./demo`（相同） |
| Profiling | `msprof op simulator`（有 48 核 bug） | PEM toml + trace.json |
| 新工具 | - | **`cannsim`**（仅 Ascend950） |
| 支持芯片 | 910B, 310P | **+ Ascend950PR, KirinX90, 920A** |

### 9.0.0 新增：cannsim（Ascend950 专用）

```bash
# 一键仿真 + 生成报告
cannsim record -s Ascend950 -g -o ./output ./demo

# 生成流水线图
cannsim report -e ./output -o ./pipeline -n all
```

> **注意**：`cannsim` 目前仅支持 Ascend950 系列，Ascend910B 仍用 LD_PRELOAD 方式。

---

## 仿真方法

详细指南见 [仿真方法指南.md](仿真方法指南.md)，包含 7 种方法：

| 方法 | 用途 | 启动方式 |
|------|------|----------|
| **PEM 仿真** | 运行验证 + cycle 统计 | `LD_PRELOAD=... ./demo` |
| **PEM toml** | 各 core/block cycle 分析 | 同上，自动生成 `profile_*.toml` |
| **msprof op simulator** | 硬件指标采样 | `msprof op simulator ./demo` |
| **cannsim**（9.0+）| 仿真 + profiling + 报告 | `cannsim record -s Ascend950 ./demo` |
| **CPU Debug** | printf + GDB 调试 | 直接 `./add`（tikicpulib） |
| **mssanitizer** | 内存/并发正确性 | `mssanitizer --tool=memcheck ./demo` |
| **msopgen sim** | 流水线可视化 | `msopgen sim -c 0 -d dump/` |

---

## 可用算子

### 内置示例（`asc-devkit-8.5.0/examples/`）

| 类别 | 算子 |
|------|------|
| 基础 | `add`, `sub`, `matmul`, `reduce`, `broadcast`, `addn`, `helloworld` |
| 融合 | `matmulleakyrelu` |
| 向量 | `vectoradd`, `unaligned_abs`, `unaligned_reducemin`, `unaligned_wholereducesum` |
| 高阶 | `addcdiv`, `scatter`, `group_matmul`, `aicpu_tiling` |
| 调试 | `cpudebug`, `printf`, `assert`, `dumptensor` |

### 自定义算子（`custom_ops/`）

- [matmul_1024_8192_4096](custom_ops/matmul_1024_8192_4096/) — 48 核 MatMul M=1024 K=8192 N=4096，精度验证通过 ✅

---

## 自定义算子开发

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.16)
find_package(ASC REQUIRED HINTS $ENV{ASCEND_INSTALL_PATH}/compiler/tikcpp/ascendc_kernel_cmake)
project(kernel_samples LANGUAGES ASC CXX)
add_executable(demo my_kernel.asc)
target_link_libraries(demo PRIVATE tiling_api register platform m dl)
target_compile_options(demo PRIVATE $<$<COMPILE_LANGUAGE:ASC>:--npu-arch=dav-2201>)
```

### 编译运行

```bash
# 8.5.0
cmake -B build -DCMAKE_ASC_RUN_MODE=cpu
# 9.0.0
cmake -B build -DCMAKE_ASC_ARCHITECTURES=dav-2201

cmake --build build -j
cd build

# 仿真运行
export LD_LIBRARY_PATH=<simulator_lib>:<ascend_lib64>:<devlib>
LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so" ./demo
```

---

## 切换到 NPU 上板

```bash
# NPU 服务器上
bash enter_npu.sh Ascend910B2

# 容器内编译运行（不加 LD_PRELOAD！）
cd /workspace/custom_ops/matmul_1024_8192_4096
cmake -B build && cmake --build build -j
cd build && ./matmul_1024_8192_4096

# Profiling（真机 msprof）
msprof op --application=./matmul_1024_8192_4096 --aic-metrics=PipeUtilization,Memory
```

算子代码完全不用改，仿真时加 `LD_PRELOAD`，上板时去掉。

---

## ACLNN 直调（零 Kernel 代码）

如果只需要调 CANN **已有的算子**（MatMul、Add、LayerNorm 等），直接用 ACLNN API，**完全不用写 AscendC kernel**。

### vs AscendC kernel

| | AscendC kernel 开发 | ACLNN 直调 |
|------|------|------|
| 代码量 | 120+ 行 `.asc` + CMakeLists | ~100 行 `.cpp`，g++ 直接编译 |
| 需要写 kernel？ | ✅ CopyIn→Compute→CopyOut | ❌ 不需要 |
| 需要写 tiling？ | ✅ MultiCoreMatmulTiling | ❌ CANN 自动 |
| 需要管分核？ | ✅ CalcGMOffset | ❌ CANN 自动 |
| 精度 | 需自己验证 | CANN 保证 |
| 适用场景 | 开发新算子 | **调已有算子直接用** |

### 两段式 API

```cpp
// 第一步：算 workspace
aclnnMatmulGetWorkspaceSize(aTensor, bTensor, cTensor, 0, &wsSize, &executor);
// 第二步：执行
aclnnMatmul(workspace, wsSize, executor, stream);
```

### 示例：aclnn_matmul

```bash
cd custom_ops/aclnn_matmul

# 编译（g++，不需要 cmake/ASC 编译器）
g++ -std=c++17 -O2 -o aclnn_matmul aclnn_matmul.cpp \
    -I/usr/local/Ascend/cann-9.0.0/aarch64-linux/include \
    -L/usr/local/Ascend/cann-9.0.0/aarch64-linux/lib64 \
    -lopapi -lascendcl -lnnopbase -lge_runner -lgraph -lrt -ldl -lpthread

# 仿真
python3 gen_data.py
LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so" ./aclnn_matmul
```

> 实测 MatMul 256×512×256：0 errors, 84867 ticks, 2.6s

### 可用算子速览

```bash
ls /usr/local/Ascend/cann-9.0.0/aarch64-linux/include/aclnnop/ | sed s/aclnn_// | sed s/\.h//
```

头文件在 `aarch64-linux/include/aclnnop/`，每个算子都是相同的两段式 API。

---

## 迁移到另一台服务器

```bash
# 打包代码（不含构建产物，约 50KB）
tar --exclude='*/build*' --exclude='*.bin' --exclude='asc-devkit*' --exclude='asc-tools*' \
    -czf ascend_cpu.tar.gz ascend_cpu/

# 传到服务器
scp ascend_cpu.tar.gz user@server:/path/

# 服务器上
tar -xzf ascend_cpu.tar.gz && cd ascend_cpu
docker build -t ascend-cpu-debug:8.5.0-910b .  # 或 -f Dockerfile.x86_64
bash enter.sh
```

---

## 目录结构

```
ascend_cpu/
├── Dockerfile              # CANN 8.5.0 镜像（ARM64）
├── Dockerfile.x86_64       # CANN 8.5.0 镜像（x86_64）
├── Dockerfile.cann9        # CANN 9.0.0 镜像（基于官方）
├── build_image.sh          # 构建 8.5.0 镜像
├── build_image_9.sh        # 构建 9.0.0 镜像
├── enter.sh                # 进入容器（仿真）
├── enter_npu.sh            # 进入容器（NPU 上板）
├── check_env.sh            # 检查 CANN 环境
├── run_operator.sh         # 一键编译运行算子
├── run_cpudebug_add.sh     # CPU debug 示例
├── custom_ops/             # 自定义算子
├── docker-config/          # Docker 配置
├── README.md               # 本文件
└── 仿真方法指南.md          # 7 种仿真方法详解
```

## 常见问题

### Q: CANN 装在哪里？
Docker 容器内 `/usr/local/Ascend/cann-8.5.0/` 或 `/usr/local/Ascend/cann-9.0.0/`。Mac 上找不到是正常的，进容器才能看到。

### Q: 算子卡住不动？
没加载仿真库，HAL 层在等 NPU 硬件。确认 `LD_PRELOAD` 已设置。

### Q: 精度不通过？
8.5.0 编译需 `CMAKE_ASC_RUN_MODE=cpu`，9.0.0 需 `CMAKE_ASC_ARCHITECTURES=dav-2201`。用错会 link 到真机 HAL。

### Q: msprof op simulator 崩溃？
CANN 8.5.0 在 48 核下触发 double-free bug。升级 9.0.0 或减少 core 数，或用 PEM toml 替代。

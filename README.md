# Ascend C CANN 8.5.0 算子 CPU 仿真环境

在 Mac (Apple Silicon) 上通过 Docker 容器运行 CANN 8.5.0 算子，使用 CPU 仿真器（PEM DaVinci Model）模拟 24 个 AI Core。

## 架构

```
Mac (Apple Silicon arm64)
  └── Colima (Docker 运行时)
       └── ubuntu:22.04 ARM64 容器
            ├── CANN Toolkit 8.5.0         安装路径: /usr/local/Ascend/cann-8.5.0/
            ├── AscendC 编译器 (bisheng)    路径: /usr/local/Ascend/cann-8.5.0/bin/bisheng
            ├── CPU 仿真器 (PEM Model)      路径: /usr/local/Ascend/cann-8.5.0/tools/simulator/
            │     ├── libpem_davinci.so        周期精确 DaVinci 仿真引擎
            │     ├── libruntime_cmodel.so     运行时仿真层
            │     └── libnpu_drv.so            NPU 驱动仿真（无真实硬件）
            └── tikicpulib                  路径: /usr/local/Ascend/cann-8.5.0/tools/tikicpulib/
```

**关键机制**：通过 `LD_PRELOAD` 把仿真库（`libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so`）注入到运行时，替换真实的 NPU 驱动和 HAL 层，实现在 CPU 上仿真运行算子。

## 快速开始

### 前置条件

- macOS + Apple Silicon (arm64)
- Colima（Docker 运行时），已安装并运行
- Docker 镜像已构建：`ascend-cpu-debug:8.5.0-910b`（约 12.8GB）

### 1. 进入容器

```bash
cd /Users/xuwenqiang/Desktop/workspace/ascend_cpu_debug
bash enter.sh
```

### 2. 检查环境

```bash
bash check_env.sh
```

预期输出：
```
ASCEND_HOME_PATH=/usr/local/Ascend/cann-8.5.0
ASCEND_OPP_PATH=/usr/local/Ascend/cann-8.5.0/opp
/usr/local/Ascend/cann-8.5.0/bin/atc        ← 编译器可用
/usr/bin/gdb                                  ← 调试器可用
Python 3.10.12
```

### 3. 运行算子

```bash
# 运行单个算子
bash run_operator.sh matmul

# 批量运行
bash run_operator.sh add sub reduce matmul

# 查看所有可用算子
bash run_operator.sh
```

## 可用算子列表

### 基础算子（`00_introduction/`）

| 算子 | 文件 | 说明 |
|------|------|------|
| `add` | `01_add/basic_api_tque_add` | 加法，精度验证通过 ✅ |
| `matmul` | `02_matmul/normal_matmul` | 矩阵乘法 M=512,N=1024,K=512 |
| `matmulleakyrelu` | `03_matmulleakyrelu` | MatMul + LeakyReLU 融合算子 |
| `addn` | `04_addn` | 多输入加法 |
| `broadcast` | `05_broadcast` | 广播运算 |
| `reduce` | `06_reduce` | 规约求和 |
| `sub` | `07_sub` | 减法，精度验证通过 ✅ |
| `helloworld` | `00_helloworld` | 最简单的 AscendC 示例 |
| `unaligned_abs` | `08_unaligned_abs` | 非对齐绝对值 |
| `unaligned_reducemin` | `09_unaligned_reducemin` | 非对齐规约求最小值 |
| `unaligned_wholereducesum` | `10_unaligned_wholereducesum` | 非对齐全局规约求和 |
| `vectoradd` | `11_vectoradd` | 向量加法 |

### 调试工具（`01_utilities/`）

| 算子 | 说明 |
|------|------|
| `cpudebug` | CPU debug 模式 ｜ 精度对比 + GDB 调试 |
| `printf` | 核内 printf 调试 |
| `assert` | 核内 assert 断言 |
| `dumptensor` | 张量数据 dump（含 cube 和 vector 两种模式） |

### 高阶算子库（`03_libraries/`）

| 算子 | 说明 |
|------|------|
| `addcdiv` | AddCDiv 自定义算子库 |
| `scatter` | Scatter 自定义算子库 |

### 最佳实践（`04_best_practices/`）

| 算子 | 说明 |
|------|------|
| `group_matmul` | 分组矩阵乘法 |
| `aicpu_tiling` | AI CPU + Device Tiling 联合开发 |

## 仿真运行时日志解读

```
[INFO] AicWrapper attach AIC 0, num_vec_core=2, num_subcore=3   ← 模拟 AI Core 0
...
[INFO] AicWrapper attach AIC 23, num_vec_core=2, num_subcore=3  ← 模拟 24 个 Core
>>>>  " PEM MODEL "                                               ← PEM 仿真模型
>>>>  Total no. of 1 chip(s) Model Init Success!                  ← 1 颗芯片初始化成功
Model RUN TIME: 2205.29 ms                                        ← 仿真耗时（非真实性能）
[INFO] Total tick: 8901                                           ← cycle 数（用于性能分析）
[Success] Case accuracy is verification passed.                   ← 精度验证通过
```

> **注意**：仿真运行时间不代表真实 NPU 性能。`Total tick` 是周期精确的，可用于分析算子的计算效率。

## 自定义算子开发

### 1. 创建算子文件

在 `asc-devkit-8.5.0/examples/` 下创建目录，编写 `.asc` 算子文件：

```cpp
// my_kernel.asc
#include "kernel_operator.h"
#include "acl/acl.h"
#include "data_utils.h"

__global__ __aicore__ void my_kernel(GM_ADDR src, GM_ADDR dst) {
    // CopyIn → Compute → CopyOut
    // ...
}

int32_t main(int32_t argc, char *argv[]) {
    aclInit(nullptr);
    aclrtSetDevice(0);
    aclrtStream stream = nullptr;
    aclrtCreateStream(&stream);

    // 分配内存、加载数据、启动 kernel...

    my_kernel<<<1, nullptr, stream>>>(srcDevice, dstDevice);
    aclrtSynchronizeStream(stream);

    // 验证结果、清理资源...
    aclrtDestroyStream(stream);
    aclrtResetDevice(0);
    aclFinalize();
    return 0;
}
```

### 2. 编写 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.16)

find_package(ASC REQUIRED HINTS $ENV{ASCEND_INSTALL_PATH}/compiler/tikcpp/ascendc_kernel_cmake)

project(kernel_samples LANGUAGES ASC CXX)

add_executable(demo my_kernel.asc)

target_link_libraries(demo PRIVATE
    tiling_api
    register
    platform
    m
    dl
)

target_compile_options(demo PRIVATE
    $<$<COMPILE_LANGUAGE:ASC>:--npu-arch=dav-2201>
)
```

### 3. 编译运行

```bash
# 在容器内
cd /workspace/ascend_cpu_debug/asc-devkit-8.5.0/examples/my_operator
rm -rf build-cpu

# 编译
cmake -B build-cpu -DCMAKE_ASC_RUN_MODE=cpu
cmake --build build-cpu -j

# 运行（仿真）
cd build-cpu
export LD_LIBRARY_PATH=/usr/local/Ascend/cann-8.5.0/tools/simulator/Ascend910B1/lib:...
LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so" ./demo
```

或直接使用封装脚本：

```bash
bash run_operator.sh <你的算子名>
```

## GDB 调试

```bash
cd <算子的 build-cpu 目录>

export LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so"

gdb --args ./demo
```

在 GDB 内：
```
(gdb) set follow-fork-mode child
(gdb) break my_kernel
(gdb) run
(gdb) next
(gdb) print variable_name
(gdb) continue
```

## 目录结构

```
ascend_cpu_debug/
├── Dockerfile              # CANN 8.5.0 镜像定义（ubuntu 22.04 + CANN Toolkit + OPS）
├── build_image.sh          # 构建 Docker 镜像
├── enter.sh                # 进入 Docker 容器（交互式）
├── check_env.sh            # 检查 CANN 环境（容器内执行）
├── run_operator.sh         # 一键编译运行算子（容器内执行）
├── run_cpudebug_add.sh     # CPU debug add 示例
├── docker-config/          # Docker 配置
├── asc-devkit-8.5.0/       # AscendC 开发示例套件（CANN 8.5.0 版本）
│   └── examples/
│       ├── 00_introduction/  # 基础算子
│       ├── 01_utilities/     # 调试工具
│       ├── 03_libraries/     # 高阶算子库
│       └── 04_best_practices/# 最佳实践
├── asc-tools-8.5.0/        # Ascend 工具包（8.5.0 分支）
└── README.md               # 本文件
```

## 常见问题

### Q: CANN 装在哪里？
CANN 装在 Docker 容器内 `/usr/local/Ascend/cann-8.5.0/`，不在 Mac 宿主机上。进入容器后才能看到。

### Q: 编译报 symbol lookup error？
检查是否正确设置了 `LD_PRELOAD`，必须加载仿真库：
```bash
export LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so"
```

### Q: 算子运行卡住不动？
可能没有加载仿真库，真实 HAL 层在等待 NPU 硬件。检查 `LD_PRELOAD` 是否正确设置。

### Q: 精度验证失败？
仿真环境下 golden data 的生成可能有数据类型差异（如 reduce 算子的 uint32 vs float），算子计算逻辑本身是正确的。

### Q: 如何升级到 CANN 9.0+？
需要拉取官方 ARM64 镜像：
```bash
docker pull ascendai/cann:9.0.0-910b-ubuntu22.04-py3.11
```
然后基于该镜像重新构建开发环境。新版本支持 `ascendebug` 命令和更新的 CPU Debug 流程。

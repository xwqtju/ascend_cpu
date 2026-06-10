# ACLNN GroupedMatMulV5 — GMM 上板指南

直接从 CANN 包调 GMM 算子，零 kernel 代码。可 PEM 仿真验证编译，上真机跑性能。

## 仿真测试（Mac/服务器，验证编译通过）

```bash
# 容器内
cd /workspace/ascend_cpu/custom_ops/aclnn_gmm

# 编译
source /etc/profile.d/ascend.sh
INC=/usr/local/Ascend/cann-9.0.0/aarch64-linux/include
LIB64=/usr/local/Ascend/cann-9.0.0/aarch64-linux/lib64
ASCLIB=/usr/local/Ascend/cann-9.0.0/lib64

g++ -std=c++17 -O2 -o test_gmm test_gmm.cpp \
    -I${INC} -L${LIB64} -L${ASCLIB} \
    -lopapi -lascendcl -lnnopbase -lge_runner -lgraph \
    -lregister -lplatform -lrt -ldl -lpthread

# PEM 仿真（结果全零是正常的，PEM 不支持 GMM kernel）
SIMDIR=/usr/local/Ascend/cann-9.0.0/tools/simulator/Ascend910B1/lib
export LD_LIBRARY_PATH=${SIMDIR}:${ASCLIB}:/usr/local/Ascend/cann-9.0.0/devlib/aarch64:${LIB64}
LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so" ./test_gmm
```

## 上板实测（NPU 服务器）

### 1. 进 NPU 容器

```bash
# 910B
bash enter_npu.sh 910b Ascend910B2

# 950
bash enter_npu.sh 950 Ascend950PR_9599
```

### 2. 在容器内编译运行

```bash
cd /workspace/ascend_cpu/custom_ops/aclnn_gmm

# 编译（同上，不需要 LD_PRELOAD）
source /etc/profile.d/ascend.sh
g++ -std=c++17 -O2 -o test_gmm test_gmm.cpp \
    -I/usr/local/Ascend/cann-9.0.0/aarch64-linux/include \
    -L/usr/local/Ascend/cann-9.0.0/aarch64-linux/lib64 \
    -lopapi -lascendcl -lnnopbase -lge_runner -lgraph \
    -lregister -lplatform -lrt -ldl -lpthread

# 直接跑（不加 LD_PRELOAD！）
./test_gmm
```

### 3. msprof 上板 profiling

```bash
# 基础 profiling
msprof op \
    --application=./test_gmm \
    --output=./prof_output

# 完整硬件指标
msprof op \
    --application=./test_gmm \
    --output=./prof_output \
    --aic-metrics=PipeUtilization,Memory,MemoryL0,MemoryUB,L2Cache

# 查看结果
ls prof_output/
```

### 4. 改 shape

编辑 `test_gmm.cpp`，改这几个常量：

```cpp
const int groups = 4;      // group 数量
const int M = 128;         // 每 group 的行数
const int K = 256;         // 每 group 的 K 维度
const int N = 128;         // 每 group 的列数
```

## 仿真 vs 真机差异速查

| | 仿真 | 真机 |
|------|------|------|
| 运行命令 | `LD_PRELOAD=... ./test_gmm` | `./test_gmm` |
| profiling | ❌ msprof 不支持 | `msprof op --application=...` |
| 结果精度 | ❌ 全零（正常） | ✅ 正确输出 |
| 编译/代码 | 完全相同 | 完全相同 |

## API 参考

代码只做了 3 件事：

```cpp
// 1. 创建 TensorList（每 group 一个 tensor）
aclTensorList *tl_x = aclCreateTensorList(tensors_x, groups);

// 2. GetWorkspaceSize
aclnnGroupedMatmulV5GetWorkspaceSize(
    tl_x, tl_w, nullptr/*bias*/, .../*其他可选参数*/,
    nullptr, nullptr, nullptr, nullptr, nullptr, nullptr,
    1, 0, 0, 0,        // splitItem, groupType, groupListType, actType
    nullptr,            // tuningConfig
    tl_o, nullptr, nullptr,
    &workspaceSize, &executor);

// 3. Execute
aclnnGroupedMatmulV5(workspace, workspaceSize, executor, stream);
```

/**
 * ACLNN MatMul — 直接调 CANN 内置 aclnnMatmul，无需 AscendC kernel
 *
 * 编译: g++ -std=c++17 -o aclnn_matmul aclnn_matmul.cpp -I${INC} -L${LIB64} \
 *        -lopapi -lascendcl -lnnopbase -lge_runner -lgraph -lregister -lplatform -lrt -ldl -lpthread
 * 仿真: LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so" ./aclnn_matmul
 */

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <iostream>
#include "aclnn/acl_meta.h"
#include "aclnnop/aclnn_matmul.h"
#include "acl/acl.h"

// --- 读取 binary 文件 ---
bool ReadFile(const char *path, void *buf, size_t size) {
    FILE *f = fopen(path, "rb");
    if (!f) { std::cerr << "Cannot open: " << path << std::endl; return false; }
    fread(buf, 1, size, f);
    fclose(f);
    return true;
}

int main() {
    // === 1. 初始化 ACL ===
    aclInit(nullptr);
    aclrtSetDevice(0);
    aclrtStream stream;
    aclrtCreateStream(&stream);

    // === 2. 矩阵参数 ===
    constexpr int64_t M = 256, K = 512, N = 256;
    const size_t aSize = M * K * sizeof(uint16_t);   // half
    const size_t bSize = K * N * sizeof(uint16_t);   // half
    const size_t cSize = M * N * sizeof(float);      // float

    std::cout << "ACLNN MatMul: " << M << "x" << K << " * " << K << "x" << N << std::endl;

    // === 3. 读入测试数据（由 gen_data.py 生成） ===
    uint16_t *aHost, *bHost;
    float *goldenHost;
    aclrtMallocHost((void**)&aHost, aSize);
    aclrtMallocHost((void**)&bHost, bSize);
    aclrtMallocHost((void**)&goldenHost, cSize);

    if (!ReadFile("input/x1_gm.bin", aHost, aSize))      return 1;
    if (!ReadFile("input/x2_gm.bin", bHost, bSize))      return 1;
    if (!ReadFile("output/golden.bin", goldenHost, cSize)) return 1;

    // === 4. 分配 device 内存并拷贝 ===
    uint16_t *aDevice, *bDevice;
    float *cDevice;
    aclrtMalloc((void**)&aDevice, aSize, ACL_MEM_MALLOC_HUGE_FIRST);
    aclrtMalloc((void**)&bDevice, bSize, ACL_MEM_MALLOC_HUGE_FIRST);
    aclrtMalloc((void**)&cDevice, cSize, ACL_MEM_MALLOC_HUGE_FIRST);
    aclrtMemcpy(aDevice, aSize, aHost, aSize, ACL_MEMCPY_HOST_TO_DEVICE);
    aclrtMemcpy(bDevice, bSize, bHost, bSize, ACL_MEMCPY_HOST_TO_DEVICE);

    // === 5. 创建 aclTensor ===
    int64_t aDims[] = {M, K}, bDims[] = {K, N}, cDims[] = {M, N};

    aclTensor *aTensor = aclCreateTensor(aDims, 2, aclDataType::ACL_FLOAT16,
        nullptr, 0, aclFormat::ACL_FORMAT_ND, aDims, 2, aDevice);
    aclTensor *bTensor = aclCreateTensor(bDims, 2, aclDataType::ACL_FLOAT16,
        nullptr, 0, aclFormat::ACL_FORMAT_ND, bDims, 2, bDevice);
    aclTensor *cTensor = aclCreateTensor(cDims, 2, aclDataType::ACL_FLOAT,
        nullptr, 0, aclFormat::ACL_FORMAT_ND, cDims, 2, cDevice);

    // === 6. GetWorkspaceSize → Execute（ACLNN 标准两段式） ===
    uint64_t wsSize = 0;
    aclOpExecutor *executor = nullptr;
    aclnnMatmulGetWorkspaceSize(aTensor, bTensor, cTensor, 0, &wsSize, &executor);
    std::cout << "Workspace: " << wsSize / 1024.0 << " KB" << std::endl;

    void *ws = nullptr;
    if (wsSize > 0) aclrtMalloc(&ws, wsSize, ACL_MEM_MALLOC_HUGE_FIRST);

    aclnnMatmul(ws, wsSize, executor, stream);
    aclrtSynchronizeStream(stream);
    std::cout << "Kernel done." << std::endl;

    // === 7. 读回结果，精度验证 ===
    float *cHost;
    aclrtMallocHost((void**)&cHost, cSize);
    aclrtMemcpy(cHost, cSize, cDevice, cSize, ACL_MEMCPY_DEVICE_TO_HOST);

    int errors = 0;
    for (size_t i = 0; i < M * N; i++) {
        float diff = fabsf(cHost[i] - goldenHost[i]);
        float rel = diff / fmaxf(fabsf(goldenHost[i]), 1e-8f);
        if (diff > 1e-3f && rel > 1e-3f) {
            if (errors < 5)
                printf("  [%zu] expected=%.4f actual=%.4f diff=%.4f\n", i, goldenHost[i], cHost[i], diff);
            errors++;
        }
    }
    float ratio = (float)errors / (M * N);
    printf("Errors: %d/%lld (%.4f%%)\n", errors, (long long)(M * N), ratio * 100);
    printf("%s\n", ratio < 0.001f ? "test PASS" : "test FAIL");

    // === 8. 清理 ===
    aclDestroyTensor(aTensor); aclDestroyTensor(bTensor); aclDestroyTensor(cTensor);
    aclrtFree(aDevice); aclrtFree(bDevice); aclrtFree(cDevice);
    if (ws) aclrtFree(ws);
    aclrtFreeHost(aHost); aclrtFreeHost(bHost); aclrtFreeHost(goldenHost); aclrtFreeHost(cHost);
    aclrtDestroyStream(stream);
    aclrtResetDevice(0);
    aclFinalize();
    return 0;
}

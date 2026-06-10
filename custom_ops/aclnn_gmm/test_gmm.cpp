/**
 * ACLNN GroupedMatMulV5 — MoE 里的 GMM 算子
 * 2 groups: group0 (4x8 * 8x4), group1 (4x8 * 8x4)
 */
#include <cstdio>
#include <cmath>
#include "aclnn/acl_meta.h"
#include "aclnnop/aclnn_grouped_matmul_v5.h"
#include "acl/acl.h"

int main() {
    const int groups = 2, M = 4, K = 8, N = 4;

    aclInit(nullptr); aclrtSetDevice(0); aclrtStream s; aclrtCreateStream(&s);

    // 每个 group: x[M,K] * w[K,N] → out[M,N]
    size_t xSize = M * K * sizeof(uint16_t);  // half
    size_t wSize = K * N * sizeof(uint16_t);
    size_t oSize = M * N * sizeof(float);

    uint16_t x_h[2][M*K], w_h[2][K*N];
    float o_h[2][M*N];
    for (int g = 0; g < groups; g++) {
        for (int i = 0; i < M*K; i++) x_h[g][i] = 0x3C00;  // half(1.0)
        for (int i = 0; i < K*N; i++) w_h[g][i] = 0x4000;  // half(2.0)
    }

    // 分配 device 内存（保存 raw ptr 用于 memcpy）
    void *dx[2], *dw[2], *dy[2];
    aclTensor *tensors_x[2], *tensors_w[2], *tensors_o[2];
    for (int g = 0; g < groups; g++) {
        aclrtMalloc(&dx[g], xSize, ACL_MEM_MALLOC_HUGE_FIRST);
        aclrtMalloc(&dw[g], wSize, ACL_MEM_MALLOC_HUGE_FIRST);
        aclrtMalloc(&dy[g], oSize, ACL_MEM_MALLOC_HUGE_FIRST);
        aclrtMemcpy(dx[g], xSize, x_h[g], xSize, ACL_MEMCPY_HOST_TO_DEVICE);
        aclrtMemcpy(dw[g], wSize, w_h[g], wSize, ACL_MEMCPY_HOST_TO_DEVICE);

        int64_t xs[] = {M, K}, ws[] = {K, N}, os[] = {M, N};
        tensors_x[g] = aclCreateTensor(xs, 2, ACL_FLOAT16, nullptr, 0, ACL_FORMAT_ND, xs, 2, dx[g]);
        tensors_w[g] = aclCreateTensor(ws, 2, ACL_FLOAT16, nullptr, 0, ACL_FORMAT_ND, ws, 2, dw[g]);
        tensors_o[g] = aclCreateTensor(os, 2, ACL_FLOAT,   nullptr, 0, ACL_FORMAT_ND, os, 2, dy[g]);
    }

    aclTensorList *tl_x = aclCreateTensorList(tensors_x, groups);
    aclTensorList *tl_w = aclCreateTensorList(tensors_w, groups);
    aclTensorList *tl_o = aclCreateTensorList(tensors_o, groups);

    // GetWorkspaceSize → Execute
    uint64_t ws = 0; aclOpExecutor *ex = nullptr;
    aclnnGroupedMatmulV5GetWorkspaceSize(tl_x, tl_w, nullptr, nullptr, nullptr, nullptr, nullptr,
        nullptr, nullptr, nullptr, nullptr, nullptr,
        1, 0, 0, 0, nullptr, tl_o, nullptr, nullptr, &ws, &ex);

    printf("GMM workspc: %lu KB\n", ws / 1024);
    void *wsp = nullptr; if (ws) aclrtMalloc(&wsp, ws, ACL_MEM_MALLOC_HUGE_FIRST);
    aclnnGroupedMatmulV5(wsp, ws, ex, s);
    aclrtSynchronizeStream(s);

    // 读结果
    printf("%d groups, each %dx%d * %dx%d:\n", groups, M, K, K, N);
    for (int g = 0; g < groups; g++) {
        aclrtMemcpy(o_h[g], oSize, dy[g], oSize, ACL_MEMCPY_DEVICE_TO_HOST);
        printf("  group%d: [", g);
        for (int i = 0; i < M*N; i++) printf("%.1f%s", o_h[g][i], i<M*N-1?" ":"");
        printf("]\n");
    }
    printf("PASS\n");

    aclDestroyTensorList(tl_x); aclDestroyTensorList(tl_w); aclDestroyTensorList(tl_o);
    for (int g = 0; g < groups; g++) {
        aclDestroyTensor(tensors_x[g]); aclDestroyTensor(tensors_w[g]); aclDestroyTensor(tensors_o[g]);
        aclrtFree(dx[g]); aclrtFree(dw[g]); aclrtFree(dy[g]);
    }
    if (wsp) aclrtFree(wsp);
    aclrtDestroyStream(s); aclrtResetDevice(0); aclFinalize();
}

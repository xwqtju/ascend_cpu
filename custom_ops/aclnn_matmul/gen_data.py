#!/usr/bin/python3
"""Generate test data for aclnn matmul M=256 K=512 N=256"""
import os, numpy as np
M, N, K = 256, 256, 512
np.random.seed(42)
a = np.random.randint(1, 10, [M, K]).astype(np.float16)
b = np.random.randint(1, 10, [K, N]).astype(np.float16)
golden = np.matmul(a.astype(np.float32), b.astype(np.float32)).astype(np.float32)
os.makedirs("input", exist_ok=True); os.makedirs("output", exist_ok=True)
a.tofile("input/x1_gm.bin"); b.tofile("input/x2_gm.bin")
golden.tofile("output/golden.bin")
print(f"MatMul {M}x{K} * {K}x{N} | A={os.path.getsize('input/x1_gm.bin')/1024:.0f}KB, B={os.path.getsize('input/x2_gm.bin')/1024:.0f}KB, C={os.path.getsize('output/golden.bin')/1024:.0f}KB")

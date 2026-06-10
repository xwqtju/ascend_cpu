#!/usr/bin/python3
"""GMM: 2 groups, each 4x8 * 8x4, half precision"""
import os, numpy as np
groups, M, K, N = 2, 4, 8, 4
np.random.seed(42)
x_all = []; w_all = []; y_all = []
for g in range(groups):
    x = np.random.randint(1, 5, [M, K]).astype(np.float16)
    w = np.random.randint(1, 5, [K, N]).astype(np.float16)
    y = np.matmul(x.astype(np.float32), w.astype(np.float32)).astype(np.float32)
    x_all.append(x); w_all.append(w); y_all.append(y)
x_cat = np.concatenate(x_all); w_cat = np.concatenate(w_all); y_cat = np.concatenate(y_all)
os.makedirs("input", exist_ok=True); os.makedirs("output", exist_ok=True)
x_cat.tofile("input/x_gm.bin"); w_cat.tofile("input/w_gm.bin")
y_cat.tofile("output/golden.bin")
print(f"GMM {groups} groups, each {M}x{K} * {K}x{N}")

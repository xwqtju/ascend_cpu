#!/usr/bin/python3
"""
Generate input/golden data for matmul: M=1024, K=8192, N=4096
A: 1024 x 8192  (half)
B: 8192 x 4096  (half)
C: 1024 x 4096  (float)
"""
import os
import numpy as np

M = 1024
N = 4096
K = 8192

def gen_golden_data():
    print(f"Generating matmul data: M={M}, K={K}, N={N}")
    print(f"A: {M}x{K} half  = {M*K*2/1024/1024:.1f} MB")
    print(f"B: {K}x{N} half  = {K*N*2/1024/1024:.1f} MB")
    print(f"C: {M}x{N} float = {M*N*4/1024/1024:.1f} MB")

    # Use small integer values for reproducibility
    np.random.seed(42)
    x1_gm = np.random.randint(1, 10, [M, K]).astype(np.float16)
    x2_gm = np.random.randint(1, 10, [K, N]).astype(np.float16)

    print("Computing golden reference...")
    golden = np.matmul(x1_gm.astype(np.float32), x2_gm.astype(np.float32)).astype(np.float32)

    os.makedirs("input", exist_ok=True)
    os.makedirs("output", exist_ok=True)

    x1_gm.tofile("./input/x1_gm.bin")
    x2_gm.tofile("./input/x2_gm.bin")
    golden.tofile("./output/golden.bin")

    print(f"Data generated:")
    print(f"  ./input/x1_gm.bin   ({os.path.getsize('./input/x1_gm.bin')/1024/1024:.1f} MB)")
    print(f"  ./input/x2_gm.bin   ({os.path.getsize('./input/x2_gm.bin')/1024/1024:.1f} MB)")
    print(f"  ./output/golden.bin ({os.path.getsize('./output/golden.bin')/1024/1024:.1f} MB)")


if __name__ == "__main__":
    gen_golden_data()

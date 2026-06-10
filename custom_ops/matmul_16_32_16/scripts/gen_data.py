#!/usr/bin/python3
"""M=128,K=256,N=128 medium matmul"""
import os, numpy as np
M,N,K=128,256,128
np.random.seed(42)
x1=np.random.randint(1,10,[M,K]).astype(np.float16)
x2=np.random.randint(1,10,[K,N]).astype(np.float16)
g=np.matmul(x1.astype(np.float32),x2.astype(np.float32)).astype(np.float32)
os.makedirs("input",exist_ok=True); os.makedirs("output",exist_ok=True)
x1.tofile("./input/x1_gm.bin"); x2.tofile("./input/x2_gm.bin")
g.tofile("./output/golden.bin")
print(f"Data: {M}x{K}x{N}, A={os.path.getsize('./input/x1_gm.bin')/1024:.1f}KB B={os.path.getsize('./input/x2_gm.bin')/1024:.1f}KB")

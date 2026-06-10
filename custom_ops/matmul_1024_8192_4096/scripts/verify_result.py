#!/usr/bin/python3
"""Verify matmul result against golden."""
import sys
import numpy as np

RELATIVE_TOL = 1e-3
ABSOLUTE_TOL = 1e-5
ERROR_TOL = 1e-4

def verify_result(output, golden):
    output = np.fromfile(output, dtype=np.float32).reshape(-1)
    golden = np.fromfile(golden, dtype=np.float32).reshape(-1)

    print(f"Output shape: {output.shape}, Golden shape: {golden.shape}")
    print(f"Output sample: {output[:5]}")
    print(f"Golden sample: {golden[:5]}")

    diff = np.abs(output - golden)
    max_diff = np.max(diff)
    mean_diff = np.mean(diff)
    print(f"Max diff: {max_diff:.6f}, Mean diff: {mean_diff:.6f}")

    # Use relative tolerance for large values
    rel_diff = diff / (np.abs(golden) + 1e-8)
    different = np.where(diff > ABSOLUTE_TOL, np.where(rel_diff > RELATIVE_TOL, 1, 0), 0)
    num_diff = np.sum(different)

    error_ratio = num_diff / golden.size
    print(f"Different elements: {num_diff}/{golden.size}, error ratio: {error_ratio:.6f}")

    if error_ratio <= ERROR_TOL:
        print("test pass")
        return True
    else:
        print(f"test failed: error ratio {error_ratio:.6f} > tolerance {ERROR_TOL}")
        # Print first 10 mismatches
        bad_idx = np.where(different)[0][:10]
        for idx in bad_idx:
            print(f"  [{idx}] expected={golden[idx]:.4f}, actual={output[idx]:.4f}, diff={diff[idx]:.4f}")
        return False


if __name__ == '__main__':
    try:
        res = verify_result(sys.argv[1], sys.argv[2])
        if not res:
            raise ValueError("[ERROR] result error")
    except Exception as e:
        print(e)
        sys.exit(1)

import numpy as np, sys
out = np.fromfile(sys.argv[1], dtype=np.float32)
gold = np.fromfile(sys.argv[2], dtype=np.float32)
diff = np.max(np.abs(out - gold))
ok = np.allclose(out, gold, rtol=1e-3, atol=1e-5)
print("Max diff: %.6f" % diff)
print("All close: %s" % ok)
if not ok:
    bad = np.where(~np.isclose(out, gold, rtol=1e-3))[0][:10]
    for i in bad:
        print("  [%d] out=%.2f gold=%.2f" % (i, out[i], gold[i]))

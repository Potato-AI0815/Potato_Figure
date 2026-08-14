#!/usr/bin/env python3
"""make_fixture_png.py — create a deterministic two-panel test PNG.

Data-as-argument principle: the output path is passed via argv, never
interpolated into source. Used by run_raster_security_tests.R.

Usage: python make_fixture_png.py <output_path> [width] [height]
Writes a white image with a chromatic block (left) and a neutral block (right).
Exit: 0 success, 2 bad args, 4 internal.
"""
import sys


def main(argv):
    if len(argv) < 2:
        print("ERROR: need output path", file=sys.stderr)
        return 2
    out = argv[1]
    w = int(argv[2]) if len(argv) > 2 else 200
    h = int(argv[3]) if len(argv) > 3 else 100
    try:
        from PIL import Image
        import numpy as np
        a = np.full((h, w, 3), 255, dtype=np.uint8)
        a[10:h - 10, 10:(w // 2 - 5)] = (30, 60, 200)     # chromatic blue
        a[10:h - 10, (w // 2 + 5):w - 10] = (90, 90, 90)  # neutral gray
        Image.fromarray(a).save(out)
        return 0
    except ImportError as exc:
        print(f"ERROR: missing dependency: {exc}", file=sys.stderr)
        return 4
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 4


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""raster_measure.py — deterministic raster measurement for Potato Figure Audit.

Data-as-argument principle (v0.4.3-alpha, P0 security fix):
  The image path is ALWAYS passed as a command-line argument (sys.argv) and is
  NEVER interpolated into generated Python source code. This eliminates both
  syntax breakage (quotes/backslashes in paths) and code-injection risk.

Subcommands:
  metrics <image> [--ink-threshold N] [--panel-count N]
      Whole-image color metrics: neutral/chromatic ink fractions, accent area,
      mean saturation, per-panel mean saturation (equal-width slices),
      palette complexity proxy, panel palette similarity.

  panels <image> [--ink-threshold N] [--bboxes "x0,y0,x1,y1;..."] [--layout RxC|auto]
      Per-panel color metrics with explicit partition:
        1) --bboxes: relative coordinates [x0,y0,x1,y1] separated by ';'
        2) --layout: "RxC" grid (e.g. 2x2)
        3) default/auto: two equal-height rows

Output: exactly one JSON object on stdout.
Exit codes: 0 = success, 2 = invalid arguments, 3 = unreadable image, 4 = internal error.
"""
from __future__ import annotations

import argparse
import json
import sys

EXIT_OK = 0
EXIT_INVALID = 2
EXIT_IMAGE = 3
EXIT_INTERNAL = 4


def load_image(path: str):
    try:
        from PIL import Image
        import numpy as np  # noqa: F401
    except ImportError as exc:  # PIL/numpy unavailable -> caller maps to NOT_EVALUABLE
        print(f"ERROR: missing dependency: {exc}", file=sys.stderr)
        sys.exit(EXIT_IMAGE)
    try:
        img = Image.open(path).convert("RGB")
    except Exception as exc:
        print(f"ERROR: cannot open image: {exc}", file=sys.stderr)
        sys.exit(EXIT_IMAGE)
    import numpy as np
    return np.asarray(img).astype(float)


def saturation(mx, mn):
    import numpy as np
    return np.where(mx > 0, (mx - mn) / mx, 0)


def cmd_metrics(args) -> int:
    import numpy as np
    a = load_image(args.image)
    thr = args.ink_threshold
    panel_count = max(1, int(args.panel_count))
    h, w, _ = a.shape
    bg = np.abs(a - 255.0).max(axis=2) > thr
    if not bg.any():
        print(json.dumps({
            "n_ink": 0, "neutral_fraction": None, "neutral_ink_fraction": None,
            "chromatic_fraction": None, "chromatic_ink_fraction": None,
            "accent_area_fraction": None, "mean_saturation": None,
            "panel_mean_saturation": [], "palette_cluster_count": 0,
            "panel_palette_similarity": None,
        }))
        return EXIT_OK
    ink = a[bg]
    mx = ink.max(axis=1)
    mn = ink.min(axis=1)
    sat = saturation(mx, mn)
    chromatic = sat > 0.15
    accent = sat > 0.35
    # Quantized RGB occupancy is a deterministic palette-complexity proxy.
    q = (ink // 32).astype(int)
    clusters = int(len(np.unique(q, axis=0)))
    panel_saturation = []
    panel_hists = []
    for idx in range(panel_count):
        x0 = int(round(idx * w / panel_count))
        x1 = int(round((idx + 1) * w / panel_count))
        p = a[:, x0:x1, :]
        pbg = np.abs(p - 255.0).max(axis=2) > thr
        if not pbg.any():
            panel_saturation.append(None)
            panel_hists.append(None)
            continue
        pink = p[pbg]
        pmx = pink.max(axis=1)
        pmn = pink.min(axis=1)
        psat = saturation(pmx, pmn)
        panel_saturation.append(float(psat.mean()))
        pq = (pink // 32).astype(int)
        keys = pq[:, 0] * 64 + pq[:, 1] * 8 + pq[:, 2]
        panel_hists.append(np.bincount(keys, minlength=512).astype(float))
    sims = []
    for i in range(len(panel_hists)):
        for j in range(i + 1, len(panel_hists)):
            x, y = panel_hists[i], panel_hists[j]
            if x is None or y is None:
                continue
            den = np.linalg.norm(x) * np.linalg.norm(y)
            if den > 0:
                sims.append(float(np.dot(x, y) / den))
    out = {
        "image_size": [w, h],
        "n_ink": int(bg.sum()),
        "neutral_fraction": float((~chromatic).mean()),
        "neutral_ink_fraction": float((~chromatic).mean()),
        "chromatic_fraction": float(chromatic.mean()),
        "chromatic_ink_fraction": float(chromatic.mean()),
        "accent_area_fraction": float(accent.sum() / bg.sum()),
        "mean_saturation": float(sat.mean()),
        "panel_mean_saturation": panel_saturation,
        "palette_cluster_count": clusters,
        "panel_palette_similarity": (float(np.mean(sims)) if sims else None),
        "panel_partition_method": "equal-width slices from manifest panel count",
        "measurement_method": "PIL raster analysis, ink = non-white pixels",
        "thresholds": {"ink_threshold": thr},
    }
    print(json.dumps(out))
    return EXIT_OK


def cmd_panels(args) -> int:
    import numpy as np
    a = load_image(args.image)
    thr = args.ink_threshold
    h, w, _ = a.shape
    bg = np.abs(a - 255.0).max(axis=2) > thr

    def measure(reg, a_slice):
        if reg.sum() == 0:
            return None
        px = a_slice[reg]
        mx = px.max(axis=1)
        mn = px.min(axis=1)
        sat = saturation(mx, mn)
        chrom = sat > 0.15
        return {
            "mean_saturation": float(sat.mean()),
            "neutral_fraction": float((~chrom).mean()),
            "n_ink": int(reg.sum()),
        }

    panels = []
    bboxes_raw = args.bboxes or ""
    layout = args.layout or "auto"
    if bboxes_raw.strip():
        method = "panel_bboxes"
        for spec in bboxes_raw.split(";"):
            p = spec.split(",")
            if len(p) != 4:
                continue
            x0, y0, x1, y1 = float(p[0]), float(p[1]), float(p[2]), float(p[3])
            y0i, y1i, x0i, x1i = int(y0 * h), int(y1 * h), int(x0 * w), int(x1 * w)
            reg = bg[y0i:y1i, x0i:x1i]
            m = measure(reg, a[y0i:y1i, x0i:x1i])
            entry = {"bbox": [x0, y0, x1, y1]}
            entry.update(m if m else {"mean_saturation": None})
            panels.append(entry)
    elif "x" in layout and layout != "auto":
        method = "grid_" + layout
        try:
            rows, cols = (int(x) for x in layout.split("x"))
        except ValueError:
            print(f"ERROR: invalid --layout {layout!r}, expected RxC", file=sys.stderr)
            return EXIT_INVALID
        for r in range(rows):
            for c in range(cols):
                y0i, y1i = int(r * h / rows), int((r + 1) * h / rows)
                x0i, x1i = int(c * w / cols), int((c + 1) * w / cols)
                reg = bg[y0i:y1i, x0i:x1i]
                m = measure(reg, a[y0i:y1i, x0i:x1i])
                entry = {"row": r, "col": c}
                entry.update(m if m else {"mean_saturation": None})
                panels.append(entry)
    else:
        method = "auto_2row"
        for r in range(2):
            y0i, y1i = int(r * h / 2), int((r + 1) * h / 2)
            reg = bg[y0i:y1i, :]
            m = measure(reg, a[y0i:y1i, :])
            entry = {"row": r}
            entry.update(m if m else {"mean_saturation": None})
            panels.append(entry)
    print(json.dumps({"panels": panels, "partition_method": method, "image_size": [w, h]}))
    return EXIT_OK


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="raster_measure.py", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_metrics = sub.add_parser("metrics", help="whole-image color metrics")
    p_metrics.add_argument("image")
    p_metrics.add_argument("--ink-threshold", type=float, default=20.0)
    p_metrics.add_argument("--panel-count", type=int, default=1)
    p_metrics.set_defaults(func=cmd_metrics)

    p_panels = sub.add_parser("panels", help="per-panel color metrics")
    p_panels.add_argument("image")
    p_panels.add_argument("--ink-threshold", type=float, default=20.0)
    p_panels.add_argument("--bboxes", default="",
                          help='relative bboxes "x0,y0,x1,y1;..."')
    p_panels.add_argument("--layout", default="auto", help='"RxC" or "auto"')
    p_panels.set_defaults(func=cmd_panels)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001 — deterministic fail-closed surface
        print(f"ERROR: internal: {exc}", file=sys.stderr)
        return EXIT_INTERNAL


if __name__ == "__main__":
    sys.exit(main())

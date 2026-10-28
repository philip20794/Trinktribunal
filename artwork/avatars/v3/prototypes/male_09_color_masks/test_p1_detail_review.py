#!/usr/bin/env python3
"""Synthetic I/O smoke test; not a visual approval of the master artwork."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image

import p1_detail_review as review


def fake_masks(src):
    y, x = np.ogrid[:1536, :1229]
    return {
        "skin": ((x > 300) & (x < 700) & (y > 290) & (y < 1000)).astype(np.float32),
        "hair": ((x > 350) & (x < 780) & (y < 280)).astype(np.float32),
        "shirt": ((x > 400) & (x < 880) & (y > 1050)).astype(np.float32),
    }


def fake_recolor(src, masks, skin="original", hair="original", shirt="original"):
    out = src.copy()
    for name, value in (("skin", skin), ("hair", hair), ("shirt", shirt)):
        if value != "original":
            out[masks[name] > 0] = (50, 110, 145)
    return out


class P1DetailReviewSmokeTest(unittest.TestCase):
    def test_creates_full_resolution_diagnostics_without_touching_source(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "synthetic.png"
            Image.new("RGB", (1229, 1536), (190, 140, 95)).save(source)
            source_before = source.read_bytes()
            out = root / "results"
            with patch.object(review, "make_masks", side_effect=fake_masks), \
                 patch.object(review, "recolor", side_effect=fake_recolor), \
                 patch.object(sys, "argv", ["p1_detail_review.py", "--source", str(source), "--out", str(out)]):
                review.main()
            metrics = json.loads((out / "p1_detail_metrics.json").read_text(encoding="utf-8"))
            self.assertEqual(metrics["review_status"], "NOT_VISUALLY_APPROVED")
            self.assertEqual(len(metrics["detail_files"]), 8)
            self.assertEqual(len(metrics["variants"]), 15)
            self.assertEqual(source.read_bytes(), source_before)
            for key, stats in metrics["variants"].items():
                self.assertEqual(stats["changed_outside_zero_alpha"], 0, key)
            for key, (left, top, right, bottom) in review.AREAS.items():
                with Image.open(out / f"detail_{key}.png") as image:
                    width = right - left
                    height = bottom - top
                    self.assertEqual(image.size, (7 * (width + 12) + 12, height + 40 + 24))


if __name__ == "__main__":
    unittest.main()

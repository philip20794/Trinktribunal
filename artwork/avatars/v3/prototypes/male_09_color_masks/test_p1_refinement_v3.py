"""P1 v3 real-master regression checks; pixel checks are not artistic approval."""
import os
from pathlib import Path
import unittest

import numpy as np
from PIL import Image

from color_mask_pilot import make_masks
from p1_mask_refinement_v2 import refine_masks
from p1_visual_tuning import EXPECTED
from p1_mask_refinement_v3 import refine_v3, recolor_v3


class TestP1V3OnOriginal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        src = (Path(os.environ["TT_P1_SOURCE"]) if "TT_P1_SOURCE" in os.environ
               else Path(__file__).resolve().parents[5] /
               "docs/avatars/references/master-male-09-approved.png")
        cls.rgb = np.asarray(Image.open(src).convert("RGB"))
        cls.baseline = make_masks(cls.rgb)
        cls.previous = refine_masks(cls.rgb, cls.baseline)
        cls.masks = refine_v3(cls.rgb, cls.previous)

    def test_source_shape_and_baseline(self):
        self.assertEqual(self.rgb.shape,(1536,1229,3))
        self.assertEqual(
            {k:int(np.count_nonzero(v>.35)) for k,v in self.baseline.items()},
            EXPECTED)
        self.assertEqual(set(self.masks),{"skin","hair","brows","shirt"})
        self.assertGreater(
            int(np.count_nonzero(self.masks["hair"]>.35)),
            int(np.count_nonzero(self.previous["hair"]>.35)))
        for alpha in self.masks.values():
            self.assertEqual(alpha.shape,(1536,1229))
            self.assertGreaterEqual(float(alpha.min()),0.0)
            self.assertLessEqual(float(alpha.max()),1.0)

    def test_no_strong_mask_overlap(self):
        keys=list(self.masks)
        for i,a in enumerate(keys):
            for b in keys[i+1:]:
                overlap=np.count_nonzero((self.masks[a]>.35)&(self.masks[b]>.35))
                self.assertEqual(int(overlap),0,f"{a}/{b}")

    def test_background_and_sign_untouched(self):
        union=np.maximum.reduce(list(self.masks.values()))
        self.assertEqual(int(np.count_nonzero(union[80:600,20:240]>.01)),0)
        self.assertEqual(int(np.count_nonzero(union[1150:1300,380:825]>.01)),0)

    def test_changes_confined_to_masks(self):
        union=np.maximum.reduce(list(self.masks.values()))
        for settings in (
            {"skin":"deep","hair":"gray","shirt":"forest"},
            {"skin":"deep","hair":"blond","shirt":"blue"},
            {"skin":"light","hair":"blond","shirt":"red"},
            {"skin":"brown","hair":"copper","shirt":"blue"},
        ):
            with self.subTest(**settings):
                colored=recolor_v3(self.rgb,self.masks,**settings)
                diff=np.any(colored!=self.rgb,axis=2)
                self.assertEqual(int(np.count_nonzero(diff&(union==0))),0)
                self.assertEqual(int(np.count_nonzero(diff[80:600,20:240])),0)
                self.assertEqual(int(np.count_nonzero(diff[1150:1300,380:825])),0)


if __name__=="__main__":
    unittest.main()

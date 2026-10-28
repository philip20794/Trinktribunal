"""P1 source-image regression tests; passing does not imply visual approval."""
import os
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from color_mask_pilot import make_masks
from p1_visual_tuning import EXPECTED
from p1_mask_refinement_v2 import refine_masks, recolor_v2


class TestRefinementOnSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = (Path(os.environ['TT_P1_SOURCE']) if os.environ.get('TT_P1_SOURCE')
                else Path(__file__).resolve().parents[5] / 'docs/avatars/references/master-male-09-approved.png')
        cls.src = np.array(Image.open(path).convert('RGB'))
        cls.baseline = make_masks(cls.src)
        cls.masks = refine_masks(cls.src, cls.baseline)

    def test_dimensions_and_baseline(self):
        self.assertEqual(self.src.shape,(1536,1229,3))
        counts={k:int(np.count_nonzero(v>.35)) for k,v in self.baseline.items()}
        self.assertEqual(counts,EXPECTED)
        self.assertEqual(set(self.masks),{'skin','hair','brows','shirt'})
        self.assertTrue(all(a.shape==(1536,1229) for a in self.masks.values()))
        self.assertGreater(np.count_nonzero(self.masks['brows']>.35),1000)

    def test_protected_wall_and_sign(self):
        union=np.maximum.reduce(list(self.masks.values()))
        self.assertFalse(np.any(union[80:600,20:240]>.01))
        self.assertFalse(np.any(union[1150:1300,380:825]>.01))

    def test_recolored_pixels_only_in_masks(self):
        union=np.maximum.reduce(list(self.masks.values()))
        cases=(
            {'hair':'blond'},
            {'skin':'deep','hair':'gray','shirt':'forest'},
            {'skin':'light','hair':'blond','shirt':'red'},
            {'skin':'brown','hair':'copper','shirt':'blue'},
        )
        for kwargs in cases:
            with self.subTest(**kwargs):
                result=recolor_v2(self.src,self.masks,**kwargs)
                changed=np.any(result!=self.src,axis=2)
                self.assertEqual(int(np.count_nonzero(changed&(union==0))),0)

    def test_masks_do_not_overlap_intensely(self):
        keys=list(self.masks)
        for i,a in enumerate(keys):
            for b in keys[i+1:]:
                count=int(np.count_nonzero((self.masks[a]>.35)&(self.masks[b]>.35)))
                self.assertLessEqual(count,20)


if __name__=='__main__':
    unittest.main()

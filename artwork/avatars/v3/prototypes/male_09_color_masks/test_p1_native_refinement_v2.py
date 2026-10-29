"""Actual source-image tests. Passing is not visual approval."""
import hashlib
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from p1_native_git_master import ORIGINAL_BLOB, CASES, make_masks
from p1_native_refinement_v2 import masks_v2, recolor_v2


SOURCE = Path(__file__).resolve().parents[5] / "docs/avatars/references/master-male-09-approved.png"


class P1NativeV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw=SOURCE.read_bytes()
        cls.blob=hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()
        with Image.open(SOURCE) as im:
            cls.format=im.format
            cls.source=np.asarray(im.convert("RGB")).copy()
        cls.before=make_masks(cls.source)
        cls.masks=masks_v2(cls.source)

    def test_unmodified_source(self):
        self.assertEqual(self.blob, ORIGINAL_BLOB)
        self.assertEqual(self.format,"PNG")
        self.assertEqual(self.source.shape,(1313,1198,3))

    def test_new_hair_pixels(self):
        old=int(np.count_nonzero(self.before["hair"]>.35))
        new=int(np.count_nonzero(self.masks["hair"]>.35))
        self.assertGreater(new,old)
        self.assertEqual(set(self.masks),{"skin","hair","brows","facial_hair","vest"})

    def test_mask_isolation(self):
        keys=list(self.masks)
        union=np.maximum.reduce(list(self.masks.values()))
        for i,a in enumerate(keys):
            for b in keys[i+1:]:
                self.assertEqual(int(np.count_nonzero(
                    (self.masks[a]>.35)&(self.masks[b]>.35))),0,f"{a}/{b}")
        self.assertEqual(int(np.count_nonzero(union[941:1194,345:860]>.01)),0)
        self.assertEqual(int(np.count_nonzero(union[45:280,:160]>.01)),0)

    def test_all_variants_preserve_unmasked_pixels(self):
        union=np.maximum.reduce(list(self.masks.values()))
        for name,settings in CASES:
            with self.subTest(name=name):
                result=recolor_v2(self.source,self.masks,**settings)
                changes=np.any(result!=self.source,axis=2)
                self.assertEqual(int(np.count_nonzero(changes&(union==0))),0)
                self.assertEqual(int(np.count_nonzero(changes[941:1194,345:860])),0)
                self.assertEqual(int(np.count_nonzero(changes[45:280,:160])),0)


if __name__=="__main__":
    unittest.main()

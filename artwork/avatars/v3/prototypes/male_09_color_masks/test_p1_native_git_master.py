import unittest
from pathlib import Path
import numpy as np
from PIL import Image
from p1_native_git_master import make_masks, recolor, CASES

ROOT = Path(__file__).resolve().parents[5]
SOURCE = ROOT / "docs/avatars/references/master-male-09-approved.png"

class NativeP1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.image = np.asarray(Image.open(SOURCE).convert("RGB"))
        cls.masks = make_masks(cls.image)

    def test_exact_raster(self):
        self.assertEqual(self.image.shape, (1313,1198,3))

    def test_isolated_masks(self):
        mask = np.maximum.reduce(list(self.masks.values()))
        self.assertEqual(np.count_nonzero(mask[941:1194,345:860]>.01), 0)
        self.assertEqual(np.count_nonzero(mask[45:280,0:160]>.01), 0)
        keys = list(self.masks)
        for i,a in enumerate(keys):
            for b in keys[i+1:]:
                self.assertEqual(np.count_nonzero((self.masks[a]>.35)&(self.masks[b]>.35)), 0)

    def test_variants(self):
        union = np.maximum.reduce(list(self.masks.values()))
        for title, options in CASES:
            with self.subTest(title=title):
                img = recolor(self.image, self.masks, **options)
                changed = np.any(img != self.image, axis=2)
                self.assertEqual(np.count_nonzero(changed & (union==0)), 0)
                self.assertEqual(np.count_nonzero(changed[941:1194,345:860]), 0)

if __name__ == "__main__":
    unittest.main()

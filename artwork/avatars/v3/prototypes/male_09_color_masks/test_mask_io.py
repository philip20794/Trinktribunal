"""Synthetic mask I/O tests, not visual approval."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from mask_io import load_masks


class TestMaskIo(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'master.png'
        Image.new('RGB', (7, 9), (80, 50, 70)).save(self.source)
        self.dir = self.root / 'masks'
        self.dir.mkdir()
        for key in ('skin', 'hair', 'shirt'):
            Image.fromarray(np.full((9,7), 128, dtype=np.uint8), 'L').save(self.dir / f'mask_{key}.png')
        self.report = {
            'source_sha256': hashlib.sha256(self.source.read_bytes()).hexdigest(),
            'source_size': [7, 9],
            'visual_approval': False,
        }
        self.write_report()

    def write_report(self):
        (self.dir / 'mask_edit_report.json').write_text(json.dumps(self.report), encoding='utf8')

    def test_reads_grayscale_alpha(self):
        masks = load_masks(self.dir, self.source, (7,9))
        self.assertEqual(set(masks), {'skin', 'hair', 'shirt'})
        self.assertAlmostEqual(float(masks['hair'][1,2]), 128/255)

    def test_rejects_wrong_source_sha(self):
        self.report['source_sha256'] = '0' * 64
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            load_masks(self.dir, self.source, (7,9))

    def test_rejects_wrong_raster(self):
        Image.new('L', (8, 9), 255).save(self.dir / 'mask_skin.png')
        with self.assertRaisesRegex(ValueError, 'raster'):
            load_masks(self.dir, self.source, (7,9))

    def test_rejects_rgb_mask(self):
        Image.new('RGB', (7, 9), 'white').save(self.dir / 'mask_shirt.png')
        with self.assertRaisesRegex(ValueError, 'grayscale'):
            load_masks(self.dir, self.source, (7,9))

    def test_requires_provenance_report(self):
        (self.dir / 'mask_edit_report.json').unlink()
        with self.assertRaises(FileNotFoundError):
            load_masks(self.dir, self.source, (7,9))


if __name__ == '__main__':
    unittest.main()

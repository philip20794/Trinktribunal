"""Load source-bound, grayscale P1 masks for review and validation.

A mask generated for a different PNG must not silently be applied to this master.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

CATEGORIES = ('skin', 'hair', 'shirt')


def load_masks(mask_dir, source_path, source_size):
    """Read saved P1 masks, only with matching SHA-256 and exact source geometry.

    Arguments: mask_dir path, source_path original image path, source_size (w, h).
    The report from p1_mask_edits.py is mandatory; no silent legacy fallback.
    """
    folder = Path(mask_dir)
    report = json.loads((folder / 'mask_edit_report.json').read_text(encoding='utf-8'))
    sha = hashlib.sha256(Path(source_path).read_bytes()).hexdigest()
    if report.get('source_sha256') != sha:
        raise ValueError('Mask source SHA-256 differs from original image; reject stale masks')
    if report.get('source_size') != list(source_size):
        raise ValueError('Mask source dimensions do not match current image')
    w, h = source_size
    masks = {}
    for name in CATEGORIES:
        path = folder / f'mask_{name}.png'
        with Image.open(path) as img:
            if img.mode != 'L':
                raise ValueError(f'{path}: expected 8-bit grayscale L mask, got {img.mode}')
            if img.size != (w, h):
                raise ValueError(f'{path}: mask raster {img.size} differs from source {(w, h)}')
            masks[name] = np.asarray(img, dtype=np.float32) / 255.0
    return masks

#!/usr/bin/env python3
"""Non-destructive, source-resolution manual corrections for male_09 mask pilot.

This is a *workbench*, not an approved mask: edit coordinates must be verified
against the true 1229x1536 master. Default/empty edits do not alter masks.
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from color_mask_pilot import make_masks

SIZE = (1229, 1536)
CATEGORIES = ('skin', 'hair', 'shirt')

# Do not replace these with auto-predicted rectangles: each is derived from
# the existing male_09 pilot and needs full-resolution human inspection.
BROW_LEFT = [(421,260),(528,245),(552,286),(526,339),(431,350),(409,300)]
BROW_RIGHT = [(565,257),(699,247),(724,307),(677,345),(581,336),(561,300)]
BEARD = [(446,506),(480,519),(504,585),(555,634),(617,640),(694,540),(696,623),(658,704),(586,723),(519,700),(466,630)]


def paint_operation(shape, width, height):
    mode = shape.get('shape')
    pts = shape.get('points')
    if not isinstance(pts, list) or len(pts) < (3 if mode == 'polygon' else 1):
        raise ValueError('Operation needs a nonempty valid points array')
    coords = np.asarray(pts, dtype=np.int32)
    if coords.ndim != 2 or coords.shape[1] != 2:
        raise ValueError('Points must be [x,y] pairs')
    if np.any(coords < 0) or np.any(coords[:, 0] >= width) or np.any(coords[:, 1] >= height):
        raise ValueError('Edit coordinates outside master image')
    canvas = np.zeros((height, width), np.uint8)
    if mode == 'polygon':
        cv2.fillPoly(canvas, [coords], 255)
    elif mode == 'brush':
        radius = shape.get('radius', 0)
        if not isinstance(radius, (int, float)) or not 1 <= radius <= 80:
            raise ValueError('Brush radius must be 1..80')
        stroke = coords.reshape((-1, 1, 2))
        cv2.polylines(canvas, [stroke], False, 255, max(1, round(2 * radius)), cv2.LINE_AA)
        for x, y in coords:
            cv2.circle(canvas, (int(x), int(y)), round(radius), 255, -1, cv2.LINE_AA)
    else:
        raise ValueError('Invalid shape, use polygon or brush')
    feather = shape.get('feather', 1)
    if not isinstance(feather, (int,float)) or not 0 <= feather <= 12:
        raise ValueError('Feather must be 0..12')
    if feather:
        sigma = float(feather)
        canvas = cv2.GaussianBlur(canvas, (0, 0), sigmaX=sigma)
    return canvas.astype(np.float32) / 255


def apply_edits(original_masks, document, size=SIZE):
    if document.get('schema_version') != 1 or document.get('source_size') != list(size):
        raise ValueError('Edit schema and exact master raster size required')
    ops = document.get('operations')
    if not isinstance(ops, list):
        raise ValueError('operations must be an array')
    w, h = size
    masks = {key: np.clip(original_masks[key].astype(np.float32), 0, 1).copy() for key in CATEGORIES}
    for i, op in enumerate(ops):
        if not isinstance(op, dict) or op.get('mask') not in CATEGORIES:
            raise ValueError(f'Invalid mask in operation {i}')
        if op.get('action') not in ('include', 'exclude'):
            raise ValueError(f'Invalid action in operation {i}')
        patch = paint_operation(op, w, h)
        strength = op.get('strength', 1)
        if not isinstance(strength, (int, float)) or not 0 < strength <= 1:
            raise ValueError('strength must be >0 and <=1')
        patch *= strength
        current = masks[op['mask']]
        if op['action'] == 'include':
            masks[op['mask']] = np.maximum(current, patch)
        else:
            masks[op['mask']] = current * (1 - patch)
    return masks


def hair_groups(hair_mask):
    h, w = hair_mask.shape
    face_hair = np.zeros((h, w), np.uint8)
    for shape in (BROW_LEFT, BROW_RIGHT, BEARD):
        cv2.fillPoly(face_hair, [np.asarray(shape, np.int32)], 255)
    # Diagnostic split: separate alpha weights sum exactly to original hair.
    weight = face_hair.astype(np.float32) / 255.0
    brows_beard = hair_mask * weight
    hair_main = hair_mask * (1 - weight)
    return hair_main, brows_beard


def verify(masks, original, source_digest):
    # A pixel-isolation check remains *necessary but insufficient* for QA.
    h, w = original.shape[:2]
    total = np.maximum.reduce(list(masks.values()))
    wall = np.zeros((h, w), bool)
    wall[80:600, 20:240] = True
    sign = np.zeros((h, w), bool)
    sign[1150:1300, 380:825] = True
    data = {
        'source_sha256': source_digest,
        'source_size': [w, h],
        'mask_counts_gt_0_35': {k: int(np.count_nonzero(v > .35)) for k,v in masks.items()},
        'overlap_gt_0_01': {
            f'{a}_{b}': int(np.count_nonzero((masks[a] > .01) & (masks[b] > .01)))
            for a,b in (('skin','hair'),('skin','shirt'),('hair','shirt'))
        },
        'mask_on_wall_gt_0_01': int(np.count_nonzero((total > .01) & wall)),
        'mask_on_sign_gt_0_01': int(np.count_nonzero((total > .01) & sign)),
        'visual_approval': False,
        'notes': 'Full-resolution QA of actual colours, shadows and halos is mandatory',
    }
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--edits', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    document = json.loads(args.edits.read_text(encoding='utf-8'))
    raw = args.source.read_bytes()
    rgb = np.asarray(Image.open(args.source).convert('RGB')).copy()
    if rgb.shape[:2] != SIZE[::-1]:
        raise ValueError(f'Expected {SIZE}, got {rgb.shape[1]}x{rgb.shape[0]}')
    masks = apply_edits(make_masks(rgb), document)
    if not document['operations']:
        print('WARNING: no corrections supplied; this output is identical to pilot masks')
    args.out.mkdir(parents=True, exist_ok=True)
    for key, value in masks.items():
        Image.fromarray(np.uint8(np.round(value * 255)), 'L').save(args.out / f'mask_{key}.png')
    main_hair, facial_hair = hair_groups(masks['hair'])
    for key, value in (('hair_main', main_hair), ('brows_beard', facial_hair)):
        Image.fromarray(np.uint8(np.round(value * 255)), 'L').save(args.out / f'mask_{key}.png')
    report = verify(masks, rgb, hashlib.sha256(raw).hexdigest())
    report['edit_operations'] = len(document['operations'])
    (args.out / 'mask_edit_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Generate full-resolution, *unapproved* P1 mask/colour inspection crops.

Run after color_mask_pilot.py. All crops use source pixels 1:1; the source
image is never modified. These diagnostics do not replace a human review.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from color_mask_pilot import label_font, make_masks, recolor
from mask_io import load_masks

# Hand-selected inspection windows based on master-male-09's existing ROIs.
# Coordinates are (left, top, right, bottom), source raster: 1229x1536.
AREAS = {
    "hairline_brows": (300, 155, 880, 440),
    "nose_cheeks": (360, 330, 855, 590),
    "beard_chin": (410, 490, 755, 745),
    "neckline": (325, 625, 880, 1065),
    "left_arm_fingers": (0, 1015, 365, 1536),
    "right_arm_fingers": (865, 1015, 1229, 1536),
    "shirt_folds": (345, 885, 875, 1375),
    "sign_hands": (270, 1080, 965, 1510),
}

# Each region gets a deliberately relevant range, not just a mini contact sheet.
GROUPS = {
    "skin": ["original", "overlay", "skin_light", "skin_olive", "skin_brown", "skin_deep", "combo_deep_gray_green"],
    "hair": ["original", "overlay", "hair_black", "hair_blond", "hair_gray", "hair_copper", "combo_light_blond_red"],
    "shirt": ["original", "overlay", "shirt_forest", "shirt_blue", "shirt_red", "shirt_charcoal", "combo_brown_copper_blue"],
    "sign": ["original", "overlay", "skin_deep", "hair_blond", "shirt_red", "combo_deep_gray_green", "combo_light_blond_red"],
}
ASSIGNMENT = {
    "hairline_brows": "hair",
    "nose_cheeks": "skin",
    "beard_chin": "hair",
    "neckline": "skin",
    "left_arm_fingers": "skin",
    "right_arm_fingers": "skin",
    "shirt_folds": "shirt",
    "sign_hands": "sign",
}
OPTIONS = {
    "skin_light": dict(skin="light"),
    "skin_olive": dict(skin="olive"),
    "skin_brown": dict(skin="brown"),
    "skin_deep": dict(skin="deep"),
    "hair_black": dict(hair="black"),
    "hair_blond": dict(hair="blond"),
    "hair_gray": dict(hair="gray"),
    "hair_copper": dict(hair="copper"),
    "shirt_forest": dict(shirt="forest"),
    "shirt_blue": dict(shirt="blue"),
    "shirt_red": dict(shirt="red"),
    "shirt_charcoal": dict(shirt="charcoal"),
    "combo_deep_gray_green": dict(skin="deep", hair="gray", shirt="forest"),
    "combo_light_blond_red": dict(skin="light", hair="blond", shirt="red"),
    "combo_brown_copper_blue": dict(skin="brown", hair="copper", shirt="blue"),
}


def overlay_masks(src, masks):
    result = src.astype(np.float32)
    for key, color in (("skin", (255, 65, 50)), ("hair", (35, 125, 245)), ("shirt", (65, 215, 85))):
        alpha = (masks[key] * 0.62)[:, :, None]
        result = result * (1 - alpha) + np.asarray(color, np.float32) * alpha
    return np.uint8(np.clip(result, 0, 255))


def make_comparison(images, area, labels, path):
    x1, y1, x2, y2 = area
    w, h = x2 - x1, y2 - y1
    pad, label_h = 12, 40
    canvas = Image.new("RGB", (len(labels) * (w + pad) + pad, h + label_h + 2 * pad), "#f5f2ec")
    draw = ImageDraw.Draw(canvas)
    font = label_font(16)
    for i, key in enumerate(labels):
        x = pad + i * (w + pad)
        crop = Image.fromarray(images[key][y1:y2, x1:x2])
        canvas.paste(crop, (x, label_h + pad))  # full source resolution, no resizing
        draw.text((x, 10), key, font=font, fill="#35312b")
    canvas.save(path, optimize=True)


def make_before_after(src, baseline, corrected, area, kwargs, destination):
    """1:1 crop: unedited pilot, corrected masks, and explicit pixel-delta map."""
    original_variant = recolor(src, baseline, **kwargs)
    edited_variant = recolor(src, corrected, **kwargs)
    delta = np.max(np.abs(original_variant.astype(np.int16) - edited_variant.astype(np.int16)), axis=2)
    # Highlight any pixel changed by mask editing; bright magenta means large RGB delta.
    indicator = np.zeros_like(src)
    indicator[:, :, 0] = np.uint8(np.minimum(255, delta * 4))
    indicator[:, :, 2] = np.uint8(np.minimum(255, delta * 4))
    images = {"Pilot vorher": original_variant, "Maske nachher": edited_variant, "Pixelabweichung x4": indicator}
    make_comparison(images, area, list(images), destination)
    return int(np.count_nonzero(delta))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--mask-dir", type=Path, help="Use source-verified edited PNG masks instead of auto-generated masks")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    source_bytes = args.source.read_bytes()
    src = np.asarray(Image.open(args.source).convert("RGB")).copy()
    if src.shape[:2] != (1536, 1229):
        raise ValueError("P1 review expects exactly 1229x1536 pixels; no scaling allowed")
    masks = load_masks(args.mask_dir, args.source, (1229, 1536)) if args.mask_dir else make_masks(src)
    images = {"original": src, "overlay": overlay_masks(src, masks)}
    images.update({key: recolor(src, masks, **kwargs) for key, kwargs in OPTIONS.items()})
    for area_name, area in AREAS.items():
        make_comparison(images, area, GROUPS[ASSIGNMENT[area_name]], args.out / f"detail_{area_name}.png")
    comparisons = {}
    if args.mask_dir:
        baseline = make_masks(src)
        area_cases = {
            "skin": OPTIONS["skin_deep"],
            "hair": OPTIONS["hair_blond"],
            "shirt": OPTIONS["shirt_red"],
            "sign": OPTIONS["combo_deep_gray_green"],
        }
        for area_name, area in AREAS.items():
            key = ASSIGNMENT[area_name]
            comparisons[area_name] = make_before_after(
                src, baseline, masks, area, area_cases[key],
                args.out / f"before_after_{area_name}.png"
            )

    maxmask = np.maximum.reduce([masks[key] for key in ("skin", "hair", "shirt")])
    active = maxmask > 0
    overlaps = {}
    for a, b in (("skin", "hair"), ("skin", "shirt"), ("hair", "shirt")):
        overlaps[f"{a}_{b}"] = int(np.count_nonzero((masks[a] > .01) & (masks[b] > .01)))
    wall = np.zeros(src.shape[:2], bool)
    wall[80:600, 20:240] = True
    sign = np.zeros(src.shape[:2], bool)
    sign[1150:1300, 380:825] = True
    cases = {}
    for key, im in images.items():
        if key in ("original", "overlay"):
            continue
        changed = np.any(src != im, axis=2)
        cases[key] = {
            "changed_px": int(np.count_nonzero(changed)),
            "changed_outside_zero_alpha": int(np.count_nonzero(changed & ~active)),
            "changed_wall_px": int(np.count_nonzero(changed & wall)),
            "changed_central_sign_px": int(np.count_nonzero(changed & sign)),
        }
    report = {
        "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "source_dimensions": [1229, 1536],
        "mask_overlap_px_alpha_gt_0_01": overlaps,
        "wall_mask_px_alpha_gt_0_01": int(np.count_nonzero((maxmask > .01) & wall)),
        "central_sign_mask_px_alpha_gt_0_01": int(np.count_nonzero((maxmask > .01) & sign)),
        "variants": cases,
        "review_status": "NOT_VISUALLY_APPROVED",
        "mask_origin": "verified_edited_pngs" if args.mask_dir else "baseline_pilot",
        "baseline_vs_edited_changed_px_in_area": comparisons,
        "warning": "Zero changes outside masks cannot establish correct segmentation, edges or colours.",
        "detail_files": [f"detail_{name}.png" for name in AREAS],
    }
    (args.out / "p1_detail_metrics.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""P1 third image-review batch. Never writes Flutter/runtime assets.

Run at repo root:
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_v3_review.py \
  --source docs/avatars/references/master-male-09-approved.png \
  --out avatar-p1-review-v3
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from color_mask_pilot import make_masks, label_font
from p1_visual_tuning import EXPECTED
from p1_mask_refinement_v2 import refine_masks, recolor_v2
from p1_mask_refinement_v3 import refine_v3, recolor_v3
from verify_master_source import inspect_file

CASES = [
    ("Original", {}),
    ("Haut hell", {"skin":"light"}),
    ("Haut oliv", {"skin":"olive"}),
    ("Haut braun", {"skin":"brown"}),
    ("Haut dunkel", {"skin":"deep"}),
    ("Haare schwarz", {"hair":"black"}),
    ("Haare blond", {"hair":"blond"}),
    ("Haare grau", {"hair":"gray"}),
    ("Haare kupfer", {"hair":"copper"}),
    ("Shirt blau", {"shirt":"blue"}),
    ("Shirt rot", {"shirt":"red"}),
    ("Dunkel / Grau / Gruen", {"skin":"deep","hair":"gray","shirt":"forest"}),
    ("Hell / Blond / Rot", {"skin":"light","hair":"blond","shirt":"red"}),
    ("Braun / Kupfer / Blau", {"skin":"brown","hair":"copper","shirt":"blue"}),
]
CROPS = {
    "hairline_deep_gray": ((295,155,875,490), {"skin":"deep","hair":"gray","shirt":"forest"}),
    "hairline_deep_blond": ((295,155,875,490), {"skin":"deep","hair":"blond","shirt":"blue"}),
    "eyes_brows_gray": ((387,265,795,420), {"hair":"gray"}),
    "chin_deep_gray": ((400,495,805,810), {"skin":"deep","hair":"gray","shirt":"forest"}),
    "sign_dark": ((80,945,1130,1360), {"skin":"deep","hair":"gray","shirt":"forest"}),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--require-exact-git-source", action="store_true",
                        help="Fail if bytes do not match the approved Git master PNG")
    args = parser.parse_args()
    identity = inspect_file(args.source)
    if args.require_exact_git_source and not identity["exact_git_source_match"]:
        parser.error("Input is not the exact Git master; use an unmodified repository PNG")
    raw = args.source.read_bytes()
    src = np.asarray(Image.open(args.source).convert("RGB")).copy()
    if src.shape != (1536,1229,3):
        raise ValueError("P1 source needs exact 1229x1536 RGB raster")
    baseline = make_masks(src)
    counts = {k:int(np.count_nonzero(v>.35)) for k,v in baseline.items()}
    if counts != EXPECTED:
        raise ValueError("Source no longer matches the male_09 baseline colour counts")
    previous = refine_masks(src, baseline)
    masks = refine_v3(src, previous)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, alpha in masks.items():
        Image.fromarray(np.uint8(np.round(alpha*255)), mode="L").save(
            args.out / f"mask_{name}.png")
    page = Image.new("RGB", (1366, 4*444+10), "#f4f0e8")
    writer = ImageDraw.Draw(page)
    font = label_font(16)
    combined = np.maximum.reduce(list(masks.values()))
    wall = np.zeros(src.shape[:2], bool)
    wall[80:600,20:240] = True
    sign = np.zeros(src.shape[:2], bool)
    sign[1150:1300,380:825] = True
    variant_checks = []
    for i,(label,kwargs) in enumerate(CASES):
        rendered = recolor_v3(src,masks,**kwargs)
        x = 12+(i%4)*338
        y = 9+(i//4)*444
        page.paste(Image.fromarray(rendered).resize(
            (320,400), Image.Resampling.LANCZOS), (x,y+27))
        writer.text((x+3,y+3), label, font=font, fill="#38332d")
        for w,h in ((320,400),(96,120),(48,60)):
            Image.fromarray(rendered).resize((w,h),Image.Resampling.LANCZOS).save(
                args.out / f"variant_{i:02d}_{w}x{h}.png")
        if i in (0,6,7,11,12,13):
            Image.fromarray(rendered).save(args.out / f"full_variant_{i:02d}.png")
        changed = np.any(src!=rendered,axis=2)
        variant_checks.append({
            "name":label,
            "changed_pixels":int(np.count_nonzero(changed)),
            "outside_mask_changes":int(np.count_nonzero(changed & (combined==0))),
            "wall_changes":int(np.count_nonzero(changed & wall)),
            "central_sign_changes":int(np.count_nonzero(changed & sign)),
        })
    page.save(args.out / "p1_v3_contact_sheet.png", optimize=True)
    for key,(crop,settings) in CROPS.items():
        x1,y1,x2,y2 = crop
        w,h = x2-x1,y2-y1
        images = [
            ("Original",src),("P1 v2",recolor_v2(src,previous,**settings)),
            ("P1 v3",recolor_v3(src,masks,**settings)),
        ]
        compare = Image.new("RGB", (3*w,h+27), "#f4f0e8")
        draw = ImageDraw.Draw(compare)
        for j,(name,arr) in enumerate(images):
            compare.paste(Image.fromarray(arr).crop(crop),(j*w,27))
            draw.text((j*w+5,3),name,font=font,fill="#38332d")
        compare.save(args.out / f"detail_{key}.png")
    overlay = src.astype(np.float32)
    for key,colour in (("skin",(230,65,67)),("hair",(36,124,240)),
                       ("brows",(245,180,45)),("shirt",(90,205,80))):
        alpha = masks[key][:,:,None]*.55
        overlay = overlay*(1-alpha) + np.asarray(colour,np.float32)*alpha
    Image.fromarray(np.uint8(np.clip(overlay,0,255))).save(
        args.out / "mask_overlay.png")
    names = tuple(masks)
    overlaps = {a+"_"+b:int(np.count_nonzero((masks[a]>.35)&(masks[b]>.35)))
        for i,a in enumerate(names) for b in names[i+1:]}
    metrics = {
        "source_file_sha256":hashlib.sha256(raw).hexdigest(),
        "source_identity": identity,
        "source_rgb_sha256":hashlib.sha256(src.tobytes()).hexdigest(),
        "source_size":[1229,1536],
        "baseline_counts":counts,
        "v2_counts":{k:int(np.count_nonzero(v>.35)) for k,v in previous.items()},
        "v3_counts":{k:int(np.count_nonzero(v>.35)) for k,v in masks.items()},
        "strong_overlap":overlaps,
        "wall_mask_pixels":int(np.count_nonzero(combined[wall]>.01)),
        "sign_mask_pixels":int(np.count_nonzero(combined[sign]>.01)),
        "variants":variant_checks,
        "visual_approval":False,
        "warning":"Source RGB vs Git original and final artistic quality require separate review.",
    }
    (args.out / "metrics.json").write_text(
        json.dumps(metrics,indent=2,ensure_ascii=False),encoding="utf-8")
    if any(overlaps.values()) or any(
        t["outside_mask_changes"] or t["wall_changes"]
        or t["central_sign_changes"] for t in variant_checks):
        raise AssertionError("Mask overlap or colour isolation violation")
    print(json.dumps(metrics,indent=2,ensure_ascii=False))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Reproduce P1 master09 prototype review. Outputs are NOT production-approved."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from color_mask_pilot import make_masks, label_font
from p1_visual_tuning import EXPECTED
from p1_mask_refinement_v2 import refine_masks, recolor_v2

CASES=[
    ("Original",{}), ("Dunkle Haut",dict(skin="deep")),
    ("Haut oliv",dict(skin="olive")), ("Haut braun",dict(skin="brown")),
    ("Haare schwarz",dict(hair="black")), ("Haare blond",dict(hair="blond")),
    ("Haare grau",dict(hair="gray")), ("Haare kupfer",dict(hair="copper")),
    ("Shirt rot",dict(shirt="red")), ("Shirt blau",dict(shirt="blue")),
    ("Dunkel / Grau / Gruen",dict(skin="deep",hair="gray",shirt="forest")),
    ("Hell / Blond / Rot",dict(skin="light",hair="blond",shirt="red")),
    ("Braun / Kupfer / Blau",dict(skin="brown",hair="copper",shirt="blue")),
]
DETAILS={
    "hairline_brows":(295,160,900,435),
    "chin_neck":(385,490,815,810),
    "fingers_sign":(80,965,1130,1395),
}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",type=Path,required=True)
    ap.add_argument("--out",type=Path,required=True)
    args=ap.parse_args()
    raw=args.source.read_bytes()
    src=np.asarray(Image.open(args.source).convert("RGB")).copy()
    if src.shape[:2] != (1536,1229):
        raise ValueError("Expected source raster 1229x1536")
    old=make_masks(src)
    baseline={k:int(np.count_nonzero(v>.35)) for k,v in old.items()}
    if baseline != EXPECTED:
        raise ValueError("Source RGB does not match the baseline male09 mask counts")
    masks=refine_masks(src,old)
    args.out.mkdir(parents=True,exist_ok=True)
    for key,alpha in masks.items():
        Image.fromarray(np.uint8(np.round(alpha*255)),mode="L").save(args.out/f"mask_{key}.png")
    overlay=src.astype(np.float32)
    for key,color in [("skin",(255,65,60)),("hair",(31,128,238)),("brows",(252,174,35)),("shirt",(70,205,90))]:
        a=masks[key][:,:,None]*.60
        overlay=overlay*(1-a)+np.asarray(color,np.float32)*a
    Image.fromarray(np.uint8(overlay)).save(args.out/"p1_mask_overlay.png")
    font=label_font(16)
    page=Image.new("RGB",(1340,1764),"#f5f1e9")
    painter=ImageDraw.Draw(page)
    merged=np.maximum.reduce(list(masks.values()))
    outside=merged==0
    sign=np.zeros(src.shape[:2],bool);sign[1150:1300,380:825]=True
    wall=np.zeros(src.shape[:2],bool);wall[80:600,20:240]=True
    variant_checks={}
    for i,(label,opts) in enumerate(CASES):
        img=recolor_v2(src,masks,**opts)
        x=12+(i%4)*332;y=10+(i//4)*438
        page.paste(Image.fromarray(img).resize((320,400),Image.Resampling.LANCZOS),(x,y+26))
        painter.text((x,y),label,font=font,fill="#35312b")
        for w,h in ((320,400),(96,120),(48,60)):
            Image.fromarray(img).resize((w,h),Image.Resampling.LANCZOS).save(args.out/f"variant_{i}_{w}x{h}.png")
        if i in (0,5,6,10,11,12):
            Image.fromarray(img).save(args.out/f"full_variant_{i}.png")
        changed=np.any(img!=src,axis=2)
        variant_checks[str(i)]={
            "label":label,
            "changed_outside_zero_masks":int(np.count_nonzero(changed&outside)),
            "changed_wall":int(np.count_nonzero(changed&wall)),
            "changed_central_sign":int(np.count_nonzero(changed&sign)),
        }
    page.save(args.out/"p1_contact_sheet.png",optimize=True)
    for area,box in DETAILS.items():
        x1,y1,x2,y2=box
        candidates=[
            ("Original",src),
            ("Dunkel / Grau / Gruen",recolor_v2(src,masks,skin="deep",hair="gray",shirt="forest")),
            ("Hell / Blond / Rot",recolor_v2(src,masks,skin="light",hair="blond",shirt="red")),
        ]
        canvas=Image.new("RGB",(3*(x2-x1),(y2-y1)+33),"#f5f1e9")
        labels=ImageDraw.Draw(canvas)
        for j,(label,img) in enumerate(candidates):
            canvas.paste(Image.fromarray(img).crop(box),(j*(x2-x1),33))
            labels.text((j*(x2-x1)+6,7),label,font=font,fill="#35312b")
        canvas.save(args.out/f"detail_{area}.png")
    overlap={
        a+"_"+b:int(np.count_nonzero((masks[a]>.35)&(masks[b]>.35)))
        for a in masks for b in masks if a<b
    }
    metrics={
        "reference_file_sha256":hashlib.sha256(raw).hexdigest(),
        "reference_rgb_sha256":hashlib.sha256(src.tobytes()).hexdigest(),
        "reference_size":[1229,1536],
        "baseline_counts_alpha_gt_035":baseline,
        "refined_counts_alpha_gt_035":{k:int(np.count_nonzero(v>.35)) for k,v in masks.items()},
        "overlap_counts_alpha_gt_035":overlap,
        "mask_on_sign":int(np.count_nonzero(merged[sign]>.01)),
        "mask_on_wall":int(np.count_nonzero(merged[wall]>.01)),
        "variants":variant_checks,
        "visual_approval":False,
        "notes":"Not compared pixel-by-pixel to Git master; some hairline and brow fringes remain",
    }
    (args.out/"p1_review_metrics.json").write_text(json.dumps(metrics,indent=2),encoding="utf-8")
    print(json.dumps(metrics,indent=2))


if __name__=="__main__":
    main()

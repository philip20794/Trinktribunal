#!/usr/bin/env python3
"""P1 exact-source second-round mask and colour review (NOT approved assets)."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps, ImageDraw

from p1_native_git_master import ORIGINAL_BLOB, SIZE, CASES
from p1_native_refinement_v2 import masks_v2, recolor_v2


def run(source, out):
    source, out = Path(source), Path(out)
    raw = source.read_bytes()
    sha = hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()
    if sha != ORIGINAL_BLOB:
        raise ValueError("Only the unmodified Git-approved master is allowed")
    with Image.open(source) as im:
        if im.format != "PNG" or im.size != SIZE:
            raise ValueError("Expected a true 1198x1313 PNG")
        rgb=np.asarray(im.convert("RGB")).copy()
    masks=masks_v2(rgb)
    out.mkdir(parents=True, exist_ok=True)
    for role, alpha in masks.items():
        Image.fromarray(np.uint8(np.rint(alpha*255)),"L").save(out/f"mask_{role}.png")

    colors={"skin":(230,62,54),"hair":(31,130,229),
            "brows":(250,199,47),"facial_hair":(172,50,232),
            "vest":(60,210,82)}
    overlay=rgb.astype(np.float32)
    for role, colour in colors.items():
        a=masks[role][:,:,None]*.6
        overlay=overlay*(1-a)+np.asarray(colour,np.float32)*a
    Image.fromarray(np.uint8(overlay)).save(out/"mask_overlay_v2.png")

    sheet=Image.new("RGB",(4*304+20,4*371+16),"#f6f1e9")
    labels=ImageDraw.Draw(sheet)
    union=np.maximum.reduce(list(masks.values()))
    sign=np.zeros(rgb.shape[:2],bool); sign[941:1194,345:860]=True
    wall=np.zeros(rgb.shape[:2],bool); wall[45:280,:160]=True
    font=None
    results=[]
    for i,(title,settings) in enumerate(CASES):
        frame=recolor_v2(rgb,masks,**settings)
        x,y=12+(i%4)*304,7+(i//4)*371
        sheet.paste(ImageOps.pad(Image.fromarray(frame),(292,324),
            Image.Resampling.LANCZOS,color="#f6f1e9"),(x,y+23))
        labels.text((x,y),title,font=font,fill="#222222")
        if i in (0,3,5,6,11,12,13):
            Image.fromarray(frame).save(out/f"full_{i:02d}.png")
        for width,height in ((320,400),(96,120),(48,60)):
            ImageOps.pad(Image.fromarray(frame),(width,height),
                Image.Resampling.LANCZOS,color="#f6f1e9").save(
                out/f"preview_{i:02d}_{width}x{height}.png")
        changed=np.any(frame!=rgb,axis=2)
        results.append({
            "name":title,
            "changed_outside_mask":int(np.count_nonzero(changed & (union==0))),
            "changed_sign":int(np.count_nonzero(changed & sign)),
            "changed_wall":int(np.count_nonzero(changed & wall)),
        })
    sheet.save(out/"native_master_contact_v2.png",optimize=True)
    keys=list(masks)
    overlaps={a+"_"+b:int(np.count_nonzero((masks[a]>.35)&(masks[b]>.35)))
        for i,a in enumerate(keys) for b in keys[i+1:]}
    metrics={
        "source_blob":sha,
        "source_sha256":hashlib.sha256(raw).hexdigest(),
        "source_size":list(SIZE),
        "mask_counts_at_035":{k:int(np.count_nonzero(v>.35)) for k,v in masks.items()},
        "strong_overlaps":overlaps,
        "mask_in_sign":int(np.count_nonzero(union[sign]>.01)),
        "mask_in_wall":int(np.count_nonzero(union[wall]>.01)),
        "variants":results,
        "visual_approval":False,
    }
    (out/"metrics.json").write_text(json.dumps(metrics,indent=2,ensure_ascii=False),
                                     encoding="utf-8")
    if any(overlaps.values()) or metrics["mask_in_sign"] or metrics["mask_in_wall"] or any(
        a["changed_outside_mask"] or a["changed_sign"] or a["changed_wall"] for a in results
    ):
        raise AssertionError("An isolation rule failed; review the masks")
    return metrics


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",required=True,type=Path)
    parser.add_argument("--out",required=True,type=Path)
    args=parser.parse_args()
    print(json.dumps(run(args.source,args.out),indent=2,ensure_ascii=False))

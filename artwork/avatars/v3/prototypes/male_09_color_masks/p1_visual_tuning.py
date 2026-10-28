#!/usr/bin/env python3
"""P1 visual-tuning candidate for painted male_09; NOT production-approved.

This is specific to the 1229x1536 source. It keeps the original image intact.
Run with either the exact repository PNG or the visually matched uploaded PNG.
The pilot's three alpha>0.35 counts must match before tuning, to catch mis-ID.
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

from color_mask_pilot import make_masks, label_font


EXPECTED = {"skin":339575, "hair":72879, "shirt":224804}
CASES = [
    ("Original",{}),
    ("Haut dunkel",{"skin":"deep"}),
    ("Haut oliv",{"skin":"olive"}),
    ("Haare blond",{"hair":"blond"}),
    ("Haare grau",{"hair":"gray"}),
    ("Dunkel / Grau / Gruen",{"skin":"deep","hair":"gray","shirt":"forest"}),
    ("Hell / Blond / Rot",{"skin":"light","hair":"blond","shirt":"red"}),
    ("Braun / Kupfer / Blau",{"skin":"brown","hair":"copper","shirt":"blue"}),
]


def region(shape, points):
    result = np.zeros(shape, np.uint8)
    cv2.fillPoly(result, [np.asarray(points,np.int32)], 255)
    return result.astype(np.float32) / 255


def split_hair(mask):
    h,w=mask.shape
    goatee=region((h,w),[(605,645),(642,647),(679,689),(674,746),(640,753),(608,714)])
    return mask*(1-goatee), mask*goatee


def tune_masks(src, old):
    h,w=src.shape[:2]
    if (w,h)!=(1229,1536):
        raise ValueError("male_09 tuning only supports 1229x1536")
    skin=old["skin"].copy()
    hair=old["hair"].copy()
    shirt=old["shirt"].copy()
    hsv=cv2.cvtColor(src,cv2.COLOR_RGB2HSV)
    H,S,V=cv2.split(hsv)
    # The former skin color filter included dark warm parts of the nameplate.
    skin[(V<103)|((src[:,:,0]<115)&(src[:,:,1]<76))]=0
    sign=region((h,w),[(286,986),(858,986),(875,1013),(882,1263),(854,1296),(291,1296),(281,1250)])
    skin*=1-sign
    # Keep painted eye whites; restrict only low-saturation pixels in each eye.
    left=region((h,w),[(438,371),(462,358),(495,356),(541,374),(535,393),(512,408),(461,415),(434,396)])
    right=region((h,w),[(568,361),(595,344),(629,342),(673,347),(702,362),(697,381),(665,396),(594,391)])
    skin[((left+right)>0)&(S<110)]=0
    # Do not recolor scattered beard/stubble fragments as bright islands.
    facial=region((h,w),[(440,525),(702,520),(718,625),(699,754),(502,763),(432,642)])
    hair[facial>0]=0
    goatee=region((h,w),[(605,654),(623,640),(640,651),(653,666),(672,684),(683,713),(672,740),(646,753),(621,735),(606,708)])
    R=src[:,:,0].astype(np.int16);G=src[:,:,1].astype(np.int16);B=src[:,:,2].astype(np.int16)
    pigmented=(goatee>0)&(R<190)&(G<130)&(R>=G+7)&(G>=B-9)&(V>=30)
    hair=np.maximum(hair,cv2.GaussianBlur(pigmented.astype(np.float32),(3,3),.65))
    brow_l=region((h,w),[(404,316),(430,288),(468,276),(493,284),(511,296),(522,322),(524,347),(478,353),(436,344),(410,333)])
    brow_r=region((h,w),[(541,318),(572,304),(602,298),(637,282),(658,281),(680,297),(681,321),(646,338),(589,352),(556,348)])
    # Conservative compromise: eyebrows keep the source color rather than
    # taking on incomplete, bright yellow/white islands. Still unresolved P1.
    hair[np.maximum(brow_l,brow_r)>.1]=0
    hair=np.clip(hair,0,1)
    skin=np.clip(skin*(1-hair),0,1)
    shirt=np.clip(shirt*(1-hair)*(1-skin),0,1)
    return {"skin":skin,"hair":hair,"shirt":shirt}


def recolor_tuned(rgb,masks,skin="original",hair="original",shirt="original"):
    out=rgb.astype(np.float32).copy()
    for cat,kind in (("skin",skin),("hair",hair),("shirt",shirt)):
        if kind=="original":
            continue
        hsv=cv2.cvtColor(np.uint8(np.clip(out,0,255)),cv2.COLOR_RGB2HSV).astype(np.float32)
        H,S,V=cv2.split(hsv)
        if cat=="skin":
            if kind=="light": H[:]=np.clip(H+1,0,179);S[:]=S*.96;V[:]=np.minimum(255,V*1.03)
            elif kind=="olive": H[:]=np.clip(H*.84+2,0,179);S[:]=np.clip(S*.94+6,0,255);V[:]=V*.83
            elif kind=="brown": H[:]=np.clip(H*.82+2,0,179);S[:]=np.clip(S*.90+16,90,215);V[:]=V*.72+8
            elif kind=="deep": H[:]=np.clip(H*.87+2,0,179);S[:]=np.clip(S*.87+28,95,210);V[:]=V*.52+13
            else: raise ValueError(kind)
        elif cat=="hair":
            if kind=="black": S[:]=S*.53;V[:]=V*.43
            elif kind=="blond": H[:]=17;S[:]=np.clip(S*.48+38,0,255);V[:]=np.minimum(237,V*1.55+13)
            elif kind=="gray": S[:]=S*.07;V[:]=np.minimum(227,V*1.55+7)
            elif kind=="copper": H[:]=7;S[:]=np.clip(S*1.05+12,0,255);V[:]=np.minimum(247,V*1.2)
            else: raise ValueError(kind)
        elif cat=="shirt":
            if kind=="forest": H[:]=62;S[:]=np.minimum(255,S*.89+25);V[:]=V*.85
            elif kind=="blue": H[:]=112;S[:]=np.minimum(255,S*.88+23);V[:]=V*.95
            elif kind=="red": H[:]=0;S[:]=np.minimum(255,S+15);V[:]=V*.94
            elif kind=="charcoal": S[:]=S*.12;V[:]=V*.6
            else: raise ValueError(kind)
        converted=cv2.cvtColor(np.uint8(np.clip(cv2.merge([H,S,V]),0,255)),cv2.COLOR_HSV2RGB).astype(np.float32)
        if cat=="hair" and kind in ("blond","gray","copper"):
            cap,goatee=split_hair(masks[cat])
            hh,ss,vv=cv2.split(hsv)
            if kind=="blond": hh[:]=17;ss[:]=np.clip(ss*.56+32,0,255);vv[:]=np.minimum(165,vv*1.08+7)
            elif kind=="gray": ss[:]=ss*.10;vv[:]=np.minimum(145,vv*1.13+3)
            else: hh[:]=7;ss[:]=np.clip(ss*1.10+9,0,255);vv[:]=np.minimum(185,vv*1.12)
            face=cv2.cvtColor(np.uint8(np.clip(cv2.merge([hh,ss,vv]),0,255)),cv2.COLOR_HSV2RGB).astype(np.float32)
            out=out*(1-cap[:,:,None]-goatee[:,:,None])+converted*cap[:,:,None]+face*goatee[:,:,None]
        else:
            alpha=masks[cat][:,:,None]
            out=out*(1-alpha)+converted*alpha
    return np.uint8(np.clip(out,0,255))


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=Path)
    ap.add_argument("--out",required=True,type=Path)
    args=ap.parse_args()
    source_bytes=args.source.read_bytes()
    rgb=np.asarray(Image.open(args.source).convert("RGB")).copy()
    if tuple(rgb.shape[:2])!=(1536,1229):
        raise ValueError("Expected source 1229x1536")
    old=make_masks(rgb)
    baseline={k:int(np.count_nonzero(v>.35)) for k,v in old.items()}
    if baseline!=EXPECTED:
        raise ValueError("Source colors no longer match approved male_09 pilot: "+str(baseline))
    masks=tune_masks(rgb,old)
    args.out.mkdir(parents=True,exist_ok=True)
    for name,value in masks.items():
        Image.fromarray(np.uint8(np.round(value*255)),"L").save(args.out/f"mask_{name}.png")
    colors={"skin":(255,65,60),"hair":(31,128,238),"shirt":(70,205,90)}
    over=rgb.astype(np.float32)
    for key,color in colors.items():
        a=masks[key][:,:,None]*.62
        over=over*(1-a)+np.asarray(color,np.float32)*a
    Image.fromarray(np.uint8(over)).save(args.out/"p1_mask_overlay.png")
    sheet=Image.new("RGB",(4*332+12,2*438+12),"#f5f1e9")
    draw=ImageDraw.Draw(sheet)
    for i,(label,kw) in enumerate(CASES):
        x=12+(i%4)*332;y=10+(i//4)*438
        variant=recolor_tuned(rgb,masks,**kw)
        sheet.paste(Image.fromarray(variant).resize((320,400),Image.Resampling.LANCZOS),(x,y+26))
        draw.text((x,y),label,font=label_font(16),fill="#35312b")
        for width,height in ((320,400),(96,120),(48,60)):
            Image.fromarray(variant).resize((width,height),Image.Resampling.LANCZOS).save(args.out/f"case_{i}_{width}x{height}.png")
    sheet.save(args.out/"p1_contact_sheet.png",optimize=True)
    union=np.maximum.reduce(list(masks.values()))
    sign=np.zeros(rgb.shape[:2],bool);sign[1150:1300,380:825]=True
    wall=np.zeros(rgb.shape[:2],bool);wall[80:600,20:240]=True
    results={"source_sha256":hashlib.sha256(source_bytes).hexdigest(),
             "source_dimensions":[1229,1536],"baseline_counts":baseline,
             "tuned_counts":{k:int(np.count_nonzero(v>.35)) for k,v in masks.items()},
             "wall_mask_px":int(np.count_nonzero(union[wall]>.01)),
             "sign_mask_px":int(np.count_nonzero(union[sign]>.01)),
             "visual_approval":False,
             "warning":"Prototype from visible upload; Git source SHA not independently checked."}
    (args.out/"p1_review_metrics.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
    print(json.dumps(results,indent=2))


if __name__=="__main__":
    main()

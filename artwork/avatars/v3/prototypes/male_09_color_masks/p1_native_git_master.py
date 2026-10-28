#!/usr/bin/env python3
"""P1 exact Git-master (1198x1313) recolour experiment; NOT APPROVED.

This is deliberately not the historical 1229x1536 purple-shirt prototype.
Source locked to Git blob 1fbf3fe02f99fcb4fb03168045ea12d237c09e59.
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

ORIGINAL_BLOB = "1fbf3fe02f99fcb4fb03168045ea12d237c09e59"
SIZE = (1198, 1313)


def poly(shape, pts):
    size = shape.shape[:2] if hasattr(shape, "shape") else shape[:2]
    mask = np.zeros(size, np.uint8)
    cv2.fillPoly(mask, [np.asarray(pts, np.int32)], 255)
    return mask > 0


def combine(shape, *polys):
    size = shape.shape[:2] if hasattr(shape, "shape") else shape[:2]
    result = np.zeros(size, bool)
    for pts in polys:
        result |= poly(shape, pts)
    return result


def blur(binary, sigma=.85):
    return cv2.GaussianBlur(binary.astype(np.float32), (5, 5), sigma)


def make_masks(rgb):
    h, w = rgb.shape[:2]
    if (w, h) != SIZE:
        raise ValueError("Expected actual Git master 1198x1313")
    R, G, B = [rgb[:, :, i].astype(np.float32) for i in range(3)]
    H, S, V = cv2.split(cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV))

    # Actual curly-hair silhouette, not the purple-shirt JPEG's coordinates.
    scalp = combine(rgb,
        [(158,325),(176,234),(224,178),(279,139),(343,109),(377,62),
         (455,74),(504,49),(565,10),(637,59),(695,83),(747,128),
         (808,171),(847,226),(837,310),(779,356),(730,309),
         (670,191),(557,158),(456,204),(399,292),(403,426),
         (377,507),(307,501),(253,473),(207,429)],
        [(373,485),(414,531),(450,588),(500,658),(548,687),
         (579,656),(553,583),(506,555)],
        [(705,251),(795,245),(829,324),(793,374),(754,365)])
    brown = ((R > G*1.12) & (G > B*1.07) & (R > 27) & (G > 13)
             & (S > 44) & (V > 25) & (R < 190))
    hair = blur(scalp & brown, .70)

    brows_region = combine(rgb,
        [(397,281),(412,266),(443,247),(472,249),(511,271),
         (525,297),(493,303),(455,319),(416,347),(393,350)],
        [(551,235),(567,213),(590,197),(616,190),(640,216),
         (639,239),(602,253),(572,277)])
    brows = blur(brown & (V < 150) & brows_region, .65)

    facehair_region = combine(rgb,
        [(447,448),(496,426),(554,438),(606,408),(677,403),
         (724,375),(723,408),(678,443),(632,456),(583,465),
         (541,488),(460,500)],
        [(583,483),(630,470),(659,491),(668,545),(736,532),
         (743,615),(700,672),(630,704),(579,659),(574,578)],
        [(402,587),(455,587),(504,613),(550,661),(537,690),(468,666)])
    facial_hair = blur(facehair_region & brown & (V < 125) & (G < 104), .75)

    face = combine(rgb,
        [(417,168),(475,160),(533,172),(585,181),(641,188),
         (697,209),(737,277),(782,361),(803,462),(785,522),
         (742,574),(708,613),(651,658),(582,653),(511,615),
         (459,588),(418,527),(393,454),(398,351)],
        [(263,474),(302,460),(358,472),(406,502),(427,557),
         (391,605),(334,623),(293,602),(268,555)],
        [(782,307),(828,294),(878,313),(909,358),(898,419),
         (879,483),(827,505),(782,481)],
        [(562,642),(679,643),(697,733),(721,806),
         (691,878),(581,867),(541,790),(553,701)])
    hands = combine(rgb,
        [(191,986),(231,976),(274,986),(311,1003),(338,1041),
         (323,1157),(283,1202),(217,1209),(181,1166),(165,1060)],
        [(874,989),(926,971),(975,989),(999,1023),(1013,1122),
         (984,1185),(947,1226),(893,1199),(870,1119)],
        [(194,1186),(299,1173),(331,1246),(331,1312),(185,1312)],
        [(936,1178),(986,1185),(1023,1312),(923,1312)])
    skin_candidate = ((R > G*1.1) & (G > B*1.09)
                      & (S >= 55) & (V > 70) & (R > 95))
    skin = blur((face | hands) & skin_candidate, .85)

    # This figure has a cream shirt plus brown leather vest, not a purple T.
    # Only narrow leather panels are considered, not the whole complex outfit.
    vest_roi = combine(rgb,
        [(431,786),(474,799),(487,838),(483,889),
         (509,907),(500,922),(430,919),(399,860)],
        [(732,783),(785,799),(809,850),(829,916),
         (734,923),(713,890),(721,828)])
    leather = ((R > G*1.06) & (G > B*1.04)
               & (V < 173) & (S > 38) & (G > 20))
    vest = blur(vest_roi & leather, .85)

    candidates = dict(hair=hair,brows=brows,facial_hair=facial_hair,
                      skin=skin,vest=vest)
    precedence = ("facial_hair", "brows", "hair", "skin", "vest")
    taken = np.zeros((h,w), np.float32)
    masks = {}
    for name in precedence:
        alpha = np.clip(candidates[name], 0, 1) * (1-taken)
        alpha[(taken > .35) & (alpha > .35)] = .34
        masks[name] = np.clip(alpha,0,1)
        taken = np.clip(taken + masks[name],0,1)
    return masks


def recolor(rgb, masks, skin="original", hair="original", vest="original"):
    output = rgb.astype(np.float32).copy()
    for key, kind in (("skin",skin),("hair",hair),("brows",hair),
                      ("facial_hair",hair),("vest",vest)):
        if kind == "original":
            continue
        hsv = cv2.cvtColor(np.uint8(np.clip(output,0,255)),
                           cv2.COLOR_RGB2HSV).astype(np.float32)
        H,S,V = cv2.split(hsv)
        if key == "skin":
            if kind == "light":
                H += .5; S *= .98; V = np.minimum(255,V*1.02)
            elif kind == "olive":
                H=H*.84+3; S=S*.93+6; V=V*.83+5
            elif kind == "brown":
                H=H*.83+2; S=S*.9+12; V=V*.71+9
            elif kind == "deep":
                H=H*.83+2; S=S*.85+22; V=V*.54+14
            else:
                raise ValueError(kind)
        elif key in ("hair","brows","facial_hair"):
            factor = {"hair":1,"brows":.74,"facial_hair":.67}[key]
            if kind == "black":
                S *= .55; V *= .50+(.18*(1-factor))
            elif kind == "gray":
                S *= .11
                V = np.minimum(175 if key != "hair" else 190,
                               V*(1+.22*factor)+4)
            elif kind == "blond":
                H[:]=16; S=S*.53+40
                V = np.minimum(150 if key != "hair" else 205,
                               V*(1+.30*factor)+6)
            elif kind == "copper":
                H[:]=7; S=S*1.05+13
                V = np.minimum(233,V*(1+.25*factor))
            else:
                raise ValueError(kind)
        elif key == "vest":
            if kind == "forest":
                H[:]=61; S=S*.94+20; V=V*.95
            elif kind == "blue":
                H[:]=111; S=S*.93+18; V=np.minimum(222,V*1.04)
            elif kind == "red":
                H[:]=2; S=S*.97+18; V=np.minimum(220,V*1.04)
            elif kind == "charcoal":
                S*=.10; V*=.92
            else:
                raise ValueError(kind)
        corrected = cv2.cvtColor(
            np.uint8(np.clip(cv2.merge([H,S,V]),0,255)),
            cv2.COLOR_HSV2RGB).astype(np.float32)
        alpha = masks[key][:,:,None]
        output = output*(1-alpha)+corrected*alpha
    return np.uint8(np.clip(output,0,255))


CASES = [
    ("Original",{}),
    ("Haut oliv",{"skin":"olive"}),
    ("Haut braun",{"skin":"brown"}),
    ("Haut dunkel",{"skin":"deep"}),
    ("Haare schwarz",{"hair":"black"}),
    ("Haare blond",{"hair":"blond"}),
    ("Haare grau",{"hair":"gray"}),
    ("Haare kupfer",{"hair":"copper"}),
    ("Weste gruen",{"vest":"forest"}),
    ("Weste blau",{"vest":"blue"}),
    ("Weste rot",{"vest":"red"}),
    ("Dunkel / Grau / Gruen",{"skin":"deep","hair":"gray","vest":"forest"}),
    ("Hell / Blond / Rot",{"skin":"light","hair":"blond","vest":"red"}),
    ("Braun / Kupfer / Blau",{"skin":"brown","hair":"copper","vest":"blue"}),
]


def run(source, out, require_exact=True):
    out=Path(out)
    out.mkdir(parents=True,exist_ok=True)
    data=Path(source).read_bytes()
    blob=hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()
    with Image.open(source) as image:
        if image.format!="PNG" or image.size!=SIZE:
            raise ValueError("Expected true 1198x1313 master PNG")
        rgb=np.asarray(image.convert("RGB")).copy()
    if require_exact and blob!=ORIGINAL_BLOB:
        raise ValueError("Git source blob does not match approved master")
    masks=make_masks(rgb)
    for name,alpha in masks.items():
        Image.fromarray(np.uint8(np.round(alpha*255)),"L").save(
            out/f"mask_{name}.png")

    overlay=rgb.astype(np.float32)
    colors={"skin":(240,85,56),"hair":(33,135,234),
            "brows":(250,192,43),"facial_hair":(171,61,245),
            "vest":(79,219,91)}
    for name,color in colors.items():
        alpha=masks[name][:,:,None]*.61
        overlay=overlay*(1-alpha)+np.asarray(color,np.float32)*alpha
    Image.fromarray(np.uint8(overlay)).save(out/"mask_overlay.png")

    sheet=Image.new("RGB",(4*306+20,4*370+20),"#f6f1e9")
    draw=ImageDraw.Draw(sheet)
    try:
        font=ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",14)
    except OSError:
        font=ImageFont.load_default()
    union=np.maximum.reduce(list(masks.values()))
    sign=np.zeros(rgb.shape[:2],bool)
    sign[941:1194,345:860]=True
    wall=np.zeros(rgb.shape[:2],bool)
    wall[45:280,0:160]=True
    metrics={
        "source_size":list(SIZE),"source_blob":blob,
        "source_sha256":hashlib.sha256(data).hexdigest(),
        "mask_pixel_counts":{k:int(np.sum(v>.35)) for k,v in masks.items()},
        "overlaps":{},"variants":[],"visual_approval":False}
    keys=list(masks)
    for i,key in enumerate(keys):
        for other in keys[i+1:]:
            metrics["overlaps"][key+"_"+other]=int(np.sum(
                (masks[key]>.35)&(masks[other]>.35)))
    for i,(label,options) in enumerate(CASES):
        arr=recolor(rgb,masks,**options)
        x=12+(i%4)*306
        y=10+(i//4)*370
        sheet.paste(ImageOps.pad(Image.fromarray(arr),(292,324),Image.Resampling.LANCZOS,color="#f6f1e9"),(x,y+24))
        draw.text((x,y),label,font=font,fill="#282828")
        if i in (0,3,5,6,11,12,13):
            Image.fromarray(arr).save(out/f"full_{i:02d}.png")
        for width,height in ((320,400),(96,120),(48,60)):
            ImageOps.pad(Image.fromarray(arr),(width,height),Image.Resampling.LANCZOS,color="#f6f1e9").save(
                out/f"preview_{i:02d}_{width}x{height}.png")
        changed=np.any(arr!=rgb,axis=2)
        metrics["variants"].append({
            "name":label,
            "changed_outside_mask":int(np.count_nonzero(changed&(union==0))),
            "changed_sign":int(np.count_nonzero(changed&sign)),
            "changed_wall":int(np.count_nonzero(changed&wall))})
    sheet.save(out/"native_master_contact.png")
    metrics["sign_mask_count"]=int(np.count_nonzero(union[sign]>.01))
    metrics["wall_mask_count"]=int(np.count_nonzero(union[wall]>.01))
    (out/"metrics.json").write_text(
        json.dumps(metrics,indent=2,ensure_ascii=False),encoding="utf-8")
    return metrics


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",type=Path,required=True)
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--allow-nonmatching-source",action="store_true")
    args=parser.parse_args()
    print(json.dumps(run(args.source,args.out,
        not args.allow_nonmatching_source),indent=2,ensure_ascii=False))

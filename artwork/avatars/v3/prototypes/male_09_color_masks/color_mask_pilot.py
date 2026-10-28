#!/usr/bin/env python3
"""Non-destructive color-mask proof-of-concept for Trinktribunal master-male-09.

Reference is a completed, hand-painted raster image, not separately regenerated layers.
The masks are *prototype* semi-automated region masks and must be reviewed at full size.
Usage:
    python color_mask_pilot.py --source /path/to/master-male-09-approved.png --out /path/to/out
"""
import argparse
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE=Path(__file__).resolve().parent

def polygon(canvas, pts):
    v=np.zeros(canvas.shape[:2], np.uint8)
    cv2.fillPoly(v,[np.asarray(pts, dtype=np.int32)],255)
    return v

def smooth(mask, size=3, sigma=0.75):
    m=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(size,size)))
    return cv2.GaussianBlur(m.astype(np.float32)/255,(5,5),sigmaX=sigma)

def make_masks(rgb):
    h,w=rgb.shape[:2]
    assert (w,h)==(1229,1536), f"Pilot expects 1229x1536, got {w}x{h}; no coordinate scaling applied."
    hsv=cv2.cvtColor(rgb,cv2.COLOR_RGB2HSV)
    H,S,V=cv2.split(hsv)
    # Shirt mask: explicitly hue-select purple dye, not the sign or background.
    purple = (((H>=125)&(H<=177)&(S>34)&(V>=30))).astype(np.uint8)*255
    # Reject stray purple details beyond garment's silhouette.
    shirt_roi=polygon(rgb,[(72,931),(124,902),(217,868),(344,802),(414,757),(447,762),(498,809),(573,852),(668,814),(733,748),(765,757),(842,804),(913,840),(1007,893),(1112,984),(1179,1191),(1178,1535),(26,1535),(33,1200)])
    shirt=(purple & shirt_roi)
    # Skin roi includes exposed face/ears/neck, forearms and fingers, does not include isolated clothing.
    # Broad, overlapping candidate windows are intentional. Pixel colors, not
    # polygon boundaries, select the skin silhouette; this prevents hard seams
    # across cheeks and neckline when recoloring dark skin tones.
    face=polygon(rgb,[(393,130),(741,126),(817,320),(825,498),(782,595),(750,655),(687,715),(592,752),(486,715),(419,632),(387,531),(380,400)])
    ear_left=polygon(rgb,[(254,360),(326,320),(450,352),(469,540),(330,550),(265,466)])
    ear_right=polygon(rgb,[(686,295),(814,281),(890,335),(910,423),(843,510),(721,505)])
    neck=polygon(rgb,[(465,630),(692,625),(725,760),(843,843),(871,1028),(331,1030),(346,834),(474,747)])
    left_arm=polygon(rgb,[(123,1038),(277,1044),(310,1160),(311,1380),(263,1535),(0,1535),(0,1227)])
    right_arm=polygon(rgb,[(883,1036),(1034,1044),(1228,1232),(1228,1535),(968,1535),(891,1350)])
    skin_roi=face|ear_left|ear_right|neck|left_arm|right_arm
    # Skin warm range, not beige background (very low saturation). Keep dark line art unaltered.
    skin_candidate=((H<=24)&(S>=58)&(V>=75)&(rgb[:,:,0]>rgb[:,:,1]*1.08)).astype(np.uint8)*255
    skin=(skin_roi & skin_candidate) & cv2.bitwise_not(shirt)
    # Hair cap and deliberately separate eyebrow/beard slots.
    cap=polygon(rgb,[(309,0),(885,0),(873,190),(823,275),(745,338),(671,308),(632,243),(530,252),(451,327),(390,322),(338,251)])
    brow_left=polygon(rgb,[(421,260),(528,245),(552,286),(526,339),(431,350),(409,300)])
    brow_right=polygon(rgb,[(565,257),(699,247),(724,307),(677,345),(581,336),(561,300)])
    beard=polygon(rgb,[(446,506),(480,519),(504,585),(555,634),(617,640),(694,540),(696,623),(658,704),(586,723),(519,700),(466,630)])
    hair_roi=cap|brow_left|brow_right|beard
    warm_darks=((H<=27)&(S>=65)&(V<190)&(rgb[:,:,0] > rgb[:,:,2]*1.12)).astype(np.uint8)*255
    hair=(hair_roi & warm_darks)
    # Hard anti-overlap: source face/cloth includes hairs, isolated hair takes priority.
    skin=cv2.bitwise_and(skin,cv2.bitwise_not(hair))
    # Keep independent alpha masks (not full-body pixel recolor).
    return {"skin":smooth(skin),"hair":smooth(hair),"shirt":smooth(shirt)}

def recolor(rgb, masks, skin='original', hair='original', shirt='original'):
    out=rgb.astype(np.float32)
    variants=[('skin',skin),('hair',hair),('shirt',shirt)]
    for category,kind in variants:
        if kind=='original':continue
        m=masks[category][:,:,None]
        hsv=cv2.cvtColor(np.uint8(np.clip(out,0,255)),cv2.COLOR_RGB2HSV).astype(np.float32)
        H,S,V=cv2.split(hsv)
        if category=='skin':
            # Approximate skin-tone transfer with varying illumination preserved.
            if kind=='light': H[:]=np.clip(H+1,0,179); S[:]=S*0.96; V[:]=np.minimum(255,V*1.03)
            elif kind=='olive': H[:]=np.clip(H*0.8+2,0,179); S[:]=np.clip(S*0.93+7,0,255); V[:]=V*.78
            elif kind=='brown': H[:]=np.clip(H*.6+4,0,179); S[:]=np.maximum(145,S*.92); V[:]=V*.64
            elif kind=='deep': H[:]=np.clip(H*.5+3,0,179); S[:]=np.maximum(178,S*.99); V[:]=V*.47
            else:raise ValueError(kind)
        elif category=='hair':
            if kind=='black': S[:]=S*.5; V[:]=V*.45
            elif kind=='blond': H[:]=17; S[:]=np.clip(S*.53+44,0,255); V[:]=np.minimum(235,V*1.72+10)
            elif kind=='copper': H[:]=7; S[:]=np.clip(S*1.12+7,0,255); V[:]=np.minimum(245,V*1.30)
            elif kind=='gray': S[:]=S*.09; V[:]=np.minimum(225,V*1.67+3)
            elif kind=='purple': H[:]=145; S[:]=np.maximum(75,S*.75); V[:]=np.minimum(210,V*1.22)
            else:raise ValueError(kind)
        elif category=='shirt':
            if kind=='forest': H[:]=62; S[:]=np.minimum(255,S*.89+25); V[:]=V*.85
            elif kind=='blue': H[:]=112; S[:]=np.minimum(255,S*.88+23); V[:]=V*.95
            elif kind=='red': H[:]=0; S[:]=np.minimum(255,S*1.0+15); V[:]=V*.94
            elif kind=='charcoal': S[:]=S*.12; V[:]=V*.60
            else:raise ValueError(kind)
        converted=cv2.cvtColor(np.uint8(np.clip(cv2.merge([H,S,V]),0,255)),cv2.COLOR_HSV2RGB).astype(np.float32)
        out=out*(1-m)+converted*m
    return np.uint8(np.clip(out,0,255))

def preview_pil(rgb, size=(312,390)):
    return Image.fromarray(rgb).resize(size,Image.Resampling.LANCZOS)

def label_font(size):
    for p in ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','C:/Windows/Fonts/arial.ttf']:
        if Path(p).exists():return ImageFont.truetype(p,size)
    return ImageFont.load_default()

def contact(rgb, results, dst):
    # 4x2 grid with originals and requested combinations.
    items=[('Original',rgb)]+[(name,img) for name,img in results]
    cellw,cellh=312,390
    ncol=4;nrow=(len(items)+ncol-1)//ncol
    sheet=Image.new('RGB',(ncol*(cellw+16)+24,nrow*(cellh+66)+70),(244,241,233));d=ImageDraw.Draw(sheet)
    d.text((22,14),'TRINKTRIBUNAL – Farbmasken-Test (Originalbild bleibt unveraendert)',font=label_font(20),fill=(40,37,31))
    for i,(name,arr) in enumerate(items):
        c=i%ncol;r=i//ncol;x=24+c*(cellw+16);y=55+r*(cellh+66)
        sheet.paste(preview_pil(arr,(cellw,cellh)),(x,y))
        d.text((x+2,y+cellh+8),name,font=label_font(17),fill=(48,43,43))
    sheet.save(dst,optimize=True)

def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,default=BASE)
    args=p.parse_args(); args.out.mkdir(parents=True,exist_ok=True)
    rgb=np.asarray(Image.open(args.source).convert('RGB')).copy()
    m=make_masks(rgb)
    for k,v in m.items(): Image.fromarray(np.uint8(v*255)).save(args.out/f'mask_{k}.png')
    variants=[
        ('Haut: oliv',dict(skin='olive')),
        ('Haut: braun',dict(skin='brown')),
        ('Haut: dunkel',dict(skin='deep')),
        ('Haare: schwarz',dict(hair='black')),
        ('Haare: blond',dict(hair='blond')),
        ('Haare: grau',dict(hair='gray')),
        ('Haare: kupfer',dict(hair='copper')),
        ('Haare: lila',dict(hair='purple')),
        ('Shirt: gruen',dict(shirt='forest')),
        ('Shirt: blau',dict(shirt='blue')),
        ('Shirt: rot',dict(shirt='red')),
        ('Alle drei: oliv/schwarz/blau',dict(skin='olive',hair='black',shirt='blue')),
        ('Alle drei: dunkel/grau/gruen',dict(skin='deep',hair='gray',shirt='forest')),
        ('Alle drei: hell/blond/rot',dict(skin='light',hair='blond',shirt='red')),
    ]
    results=[]
    for name,kw in variants:
        im=recolor(rgb,m,**kw);results.append((name,im))
        if name.startswith('Alle drei:'):
            Image.fromarray(im).save(args.out/('variant_'+['a','b','c'][sum(k.startswith('Alle drei:') for k,_ in results)-1]+'.png'),optimize=True)
    contact(rgb,results[:7],args.out/'color_test_01.png')
    contact(rgb,results[7:],args.out/'color_test_02.png')
    # mask overlay on original, clearly highlighting all three independent zones
    overlay=rgb.copy().astype(np.float32)
    colors={'skin':np.array([255,70,60],np.float32),'hair':np.array([31,128,238],np.float32),'shirt':np.array([70,205,90],np.float32)}
    for k,v in m.items():overlay=overlay*(1-0.6*v[:,:,None])+colors[k]*0.6*v[:,:,None]
    Image.fromarray(np.uint8(overlay)).save(args.out/'mask_overlay.png',optimize=True)
    print('Mask nonzero pixels: '+str({k:int(np.count_nonzero(v>.35)) for k,v in m.items()}))
    print('Output:',args.out)
if __name__=='__main__':main()
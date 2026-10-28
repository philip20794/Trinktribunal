#!/usr/bin/env python3
"""Validate mask isolation and export mobile-resolution proof images."""
import argparse, json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from color_mask_pilot import make_masks,recolor,label_font

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    a=ap.parse_args(); a.out.mkdir(parents=True,exist_ok=True)
    src=np.array(Image.open(a.source).convert('RGB'))
    masks=make_masks(src)
    options={
        'olive_black_blue':dict(skin='olive',hair='black',shirt='blue'),
        'deep_gray_forest':dict(skin='deep',hair='gray',shirt='forest'),
        'light_blond_red':dict(skin='light',hair='blond',shirt='red'),
    }
    allm=np.maximum.reduce(list(masks.values()))
    outside=allm==0.0
    # Neither the wallpaper nor the sign's central name safe area may be touched.
    wall=np.zeros(src.shape[:2],bool);wall[80:600,20:240]=True
    sign=np.zeros(src.shape[:2],bool);sign[1150:1300,380:825]=True
    data={'source_size':list(src.shape[1::-1]),'mask_pixel_counts_at_alpha_gt_0.35':{k:int(np.count_nonzero(v>0.35)) for k,v in masks.items()},'mask_total_px_at_alpha_gt_0.01':int(np.count_nonzero(allm>0.01)),'wall_mask_pixels':int(np.count_nonzero(allm[wall]>0.01)),'central_sign_mask_pixels':int(np.count_nonzero(allm[sign]>0.01)), 'variants':{}}
    # Two alternatives plus original, shown at editor/lobby sizes.
    picks=[('Original',src),('Oliv / schwarz / blau',recolor(src,masks,**options['olive_black_blue'])),('Dunkel / grau / gruen',recolor(src,masks,**options['deep_gray_forest']))]
    frame=Image.new('RGB',(1000,510),'#f6f4ed');d=ImageDraw.Draw(frame)
    font=label_font(15)  # OS-independent font lookup with Pillow fallback
    labels=['320x400','96x120','48x60'];sizes=[(320,400),(96,120),(48,60)]
    for row,(label,im) in enumerate(picks):
        if row==0: y=18
        elif row==1:y=178
        else:y=337
        # Resize to target height; the 320 case is capped to 120px in the summary grid
        for col,(W,H) in enumerate(sizes):
            thumb=Image.fromarray(im).resize((W,H),Image.Resampling.LANCZOS)
            fname=f'size_{row}_{W}x{H}.png'
            thumb.save(a.out/fname)
            if row==0 and col==0:
                continue
        # a side-by-side scaled thumbnail at 128px height plus smaller previews.
        thumb=Image.fromarray(im).resize((104,130),Image.Resampling.LANCZOS)
        x=20+row*330;frame.paste(thumb,(x,y+12))
        frame.paste(Image.fromarray(im).resize((96,120),Image.Resampling.LANCZOS),(x+120,y+12))
        frame.paste(Image.fromarray(im).resize((48,60),Image.Resampling.LANCZOS),(x+235,y+20))
        d.text((x,y),label,font=font,fill='#38332d')
    # actually make a cleaner compact montage via three columns (one per outfit)
    frame=Image.new('RGB',(1150,480),'#f6f4ed');d=ImageDraw.Draw(frame)
    for col,(label,im) in enumerate(picks):
        x=20+col*376
        frame.paste(Image.fromarray(im).resize((240,300),Image.Resampling.LANCZOS),(x,55))
        frame.paste(Image.fromarray(im).resize((96,120),Image.Resampling.LANCZOS),(x+245,180))
        frame.paste(Image.fromarray(im).resize((48,60),Image.Resampling.LANCZOS),(x+275,75))
        d.text((x,15),label,font=font,fill='#38332d')
        d.text((x+5,371),'240x300 Darstellung / 96x120 / 48x60',font=font,fill='#38332d')
    frame.save(a.out/'small_sizes_review.png')
    for key,opts in options.items():
        variant=recolor(src,masks,**opts)
        outside_diff=np.any(variant!=src,axis=2)&outside
        # representative pixels showing if original backdrop/sign were accidentally recolored
        data['variants'][key]={
            'changed_px_total':int(np.count_nonzero(np.any(variant!=src,axis=2))),
            'changed_outside_masks':int(np.count_nonzero(outside_diff)),
            'changed_wall_pixels':int(np.count_nonzero(np.any(variant[wall]!=src[wall],axis=1))),
            'changed_central_sign_pixels':int(np.count_nonzero(np.any(variant[sign]!=src[sign],axis=1))),
        }
        img=Image.fromarray(variant); img.save(a.out/('pilot_'+key+'.webp'),format='WEBP',quality=88,method=6)
    (a.out/'validation_metrics.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
    print(json.dumps(data,indent=2))
if __name__=='__main__':main()
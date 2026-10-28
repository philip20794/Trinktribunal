"""Second P1 visual refinement candidate for the 1229x1536 painted male_09.

Four separate roles: skin, scalp+goatee hair, eyebrows, shirt.
Hand-calibrated on a user-uploaded visually corresponding PNG; NOT approved
and NOT verified byte-/pixel-identical to the Git master. No Flutter runtime.
"""
import cv2
import numpy as np
from p1_visual_tuning import tune_masks, recolor_tuned, region as poly


def refine_masks(rgb, baseline):
    h,w = rgb.shape[:2]
    if (w,h)!=(1229,1536): raise ValueError('Expected master male09 dimensions')
    masks=tune_masks(rgb,baseline)
    skin=masks['skin'].copy()
    hair=masks['hair'].copy()
    shirt=masks['shirt'].copy()
    hsv=cv2.cvtColor(rgb,cv2.COLOR_RGB2HSV)
    H,S,V=cv2.split(hsv)
    R,G,B=(rgb[:,:,i].astype(np.int16) for i in range(3))
    forehead=poly((h,w),[(425,200),(739,192),(779,295),(779,371),(418,382),(419,279)])
    warm_skin=(R>146)&(G>83)&(R>G*1.17)&(G>B*1.16)&(S>=65)&(V>=135)
    browleft=poly((h,w),[(419,291),(441,275),(478,273),(520,290),(559,307),(576,333),(560,351),(509,351),(462,345),(422,334)])
    browright=poly((h,w),[(614,323),(630,306),(662,294),(708,283),(738,292),(758,312),(751,332),(715,341),(670,353),(631,346)])
    brow_roi=np.maximum(browleft,browright)
    hair[brow_roi>.1]=0
    # Separate eyebrow pigment from the flat forehead regions.
    brow_pigment=((brow_roi>.1)&(R>43)&(V<184)&(S>45)&(R>G*1.06)&(G>B-11))
    brows=cv2.morphologyEx((brow_pigment*255).astype(np.uint8),cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    brows=cv2.GaussianBlur(brows,(5,5),.70).astype(np.float32)/255.0
    # Restore forehead skin that was cut out together with the old brow mask.
    _, yy = None, np.arange(h)[:,None]
    newfore=((forehead>.1)&warm_skin&(brow_roi<.1)&(yy>238))
    restored=cv2.GaussianBlur(newfore.astype(np.float32),(5,5),.7)
    skin=np.maximum(skin,restored*(1-hair))
    newbrow=((brow_roi>.1)&(R>181)&(G>99)&(V>172)&(S>=66))
    skin=np.maximum(skin,cv2.GaussianBlur(newbrow.astype(np.float32),(5,5),.65)*(1-brows))
    # Expand skin gently across the previously uncoloured right jaw edge.
    jaw=poly((h,w),[(433,505),(752,504),(777,567),(774,637),(737,708),(691,745),(615,777),(507,750),(443,701),(420,647)])
    jaw_candidate=((jaw>.1)&(R>115)&(G>55)&(R>G*1.13)&(G>B*1.12)&(V>105)&(S>48))
    jaw_blur=cv2.GaussianBlur(jaw_candidate.astype(np.float32),(5,5),.70)
    skin=np.maximum(skin,jaw_blur*(1-hair))
    # Recover dark brown side strands at the temples without touching the ears.
    side_left=poly((h,w),[(337,214),(467,212),(447,306),(450,413),(392,431),(368,344)])
    side_right=poly((h,w),[(718,207),(831,228),(821,364),(768,417),(739,344)])
    side=np.maximum(side_left,side_right)
    brown_strands=(side>.1)&(R>30)&(R<186)&(G<138)&(R>G*1.12)&(G>B-8)&(S>59)&(V>32)
    additions=cv2.GaussianBlur(brown_strands.astype(np.float32),(5,5),.65)
    hair=np.maximum(hair,additions*(1-brows))
    # Recolour warm anti-aliased pixels alongside real skin instead of leaving
    # a distinct peach-coloured jaw/forehead seam under dark skin colours.
    faceedge=poly((h,w),[(423,193),(743,191),(793,327),(774,550),(768,647),(710,746),(609,785),(485,754),(408,675),(395,402)])
    close_to_skin=cv2.dilate(np.uint8(skin>.82),np.ones((9,9),np.uint8))>0
    warm_fringe=(faceedge>.1)&close_to_skin&(R>152)&(G>84)&(S>55)&(V>130)&(hair<.48)&(brows<.45)
    skin[warm_fringe]=1
    skin*=1-brows
    hair*=1-brows
    hair*=1-skin
    shirt*=1-skin
    shirt*=1-hair
    return {'skin':np.clip(skin,0,1),
            'hair':np.clip(hair,0,1),
            'brows':np.clip(brows*(1-skin)*(1-hair),0,1),
            'shirt':np.clip(shirt,0,1)}


def recolor_v2(rgb,masks,skin='original',hair='original',shirt='original'):
    """Use base P1 transfer for skin/scalp/goatee, conservative brow transfer."""
    core={key:masks[key] for key in ('skin','hair','shirt')}
    out=recolor_tuned(rgb,core,skin=skin,hair=hair,shirt=shirt)
    if hair=='original': return out
    hsv=cv2.cvtColor(rgb,cv2.COLOR_RGB2HSV).astype(np.float32)
    H,S,V=cv2.split(hsv)
    if hair=='blond':
        H[:]=16;S[:]=np.clip(S*.45+34,0,255);V[:]=np.minimum(190,V*1.22+9)
    elif hair=='gray':
        S[:]=S*.075;V[:]=np.minimum(173,V*1.19+7)
    elif hair=='copper':
        H[:]=7;S[:]=np.clip(S*1.1+5,0,255);V[:]=np.minimum(191,V*1.14)
    elif hair=='black':
        S[:]=S*.50;V[:]=V*.63
    else: raise ValueError(hair)
    target=cv2.cvtColor(np.uint8(np.clip(cv2.merge([H,S,V]),0,255)),cv2.COLOR_HSV2RGB).astype(np.float32)
    alpha=masks['brows'][:,:,None]
    return np.uint8(np.clip(out.astype(np.float32)*(1-alpha)+target*alpha,0,255))

"""P1 source-specific colour-mask refinement for the exact 1198x1313 Git male09.

Five roles: scalp hair, brows, facial hair, skin, leather vest. Does not
change the original PNG. Outputs remain review candidates, NOT approved.
"""
import cv2
import numpy as np
from p1_native_git_master import make_masks as make_base_masks, combine, blur


def masks_v2(rgb):
    h, w = rgb.shape[:2]
    if (w, h) != (1198, 1313):
        raise ValueError("Mask requires the exact 1198x1313 male09 raster")
    m = {k: v.copy() for k, v in make_base_masks(rgb).items()}
    R, G, B = (rgb[:, :, i].astype(np.float32) for i in range(3))
    H, S, V = cv2.split(cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV))
    brown_ink = ((R > 28) & (R < 184) & (R > G*1.12)
                 & (G > B*1.055) & (G < 138) & (S >= 46) & (V >= 24))

    # Dark curls run in front of the forehead and alongside the ears.
    forehead_curls = combine(rgb,
        [(363,196),(425,159),(510,155),(558,178),(549,220),(525,256),
         (477,280),(425,296),(373,314),(371,261)],
        [(687,146),(776,141),(844,205),(839,292),(794,349),
         (756,362),(740,297),(744,234)],
        [(216,392),(296,376),(353,405),(425,453),(432,515),
         (376,544),(309,496),(235,482)])
    dark_curl = forehead_curls & brown_ink & (V < 155) & (G < 112)
    nearby = cv2.dilate(np.uint8(m["hair"] > .15),
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (71,71))) > 0
    dark_curl &= nearby
    m["hair"] = np.maximum(m["hair"],
        cv2.GaussianBlur(dark_curl.astype(np.float32), (5,5), .8))

    # Fill small gaps inside brows, but do not include lashes/eyelids.
    brow_roi = combine(rgb,
        [(382,352),(385,311),(405,281),(436,257),(473,249),(502,260),
         (524,293),(521,315),(488,324),(455,329),(425,354)],
        [(544,292),(546,254),(564,223),(599,194),(620,188),
         (646,208),(653,236),(630,256),(595,275),(560,285)])
    brow_pigment = brow_roi & brown_ink & (V < 147)
    solid = cv2.morphologyEx((brow_pigment*255).astype(np.uint8),
        cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5,5))) > 0
    m["brows"] = np.maximum(m["brows"], blur(solid, .6))

    # Restore warm skin highlights at forehead/jaw, not original dark ink.
    face_roi = combine(rgb,
        [(396,145),(435,143),(480,143),(550,151),(644,163),(728,193),
         (779,328),(810,410),(774,550),(711,610),(650,654),
         (576,666),(506,630),(438,579),(387,490),(386,347)])
    warm = (face_roi & (R > 106) & (R > G*1.12)
            & (G > B*1.07) & (S > 49) & (V > 77))
    closed = cv2.morphologyEx((warm*255).astype(np.uint8),
        cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5,5)))
    m["skin"] = np.maximum(m["skin"], blur(closed > 0, .9)*.96)

    # One strong role per pixel; original dark facial stubble stays detailed.
    occupied = np.zeros((h,w), np.float32)
    result = {}
    for name in ("hair", "brows", "facial_hair", "skin", "vest"):
        alpha = np.clip(m[name], 0, 1)*(1-occupied)
        alpha[(alpha > .35) & (occupied > .35)] = .34
        result[name] = np.clip(alpha, 0, 1)
        occupied = np.clip(occupied + result[name], 0, 1)
    return result


def recolor_v2(rgb, masks, skin="original", hair="original", vest="original"):
    """Grade each semantic role from original RGB, not from earlier grades."""
    out = rgb.astype(np.float32).copy()
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    srcH, srcS, srcV = cv2.split(hsv)
    for role, kind in (("skin",skin), ("hair",hair), ("brows",hair),
                       ("facial_hair",hair), ("vest",vest)):
        if kind == "original":
            continue
        H, S, V = srcH.copy(), srcS.copy(), srcV.copy()
        if role == "skin":
            if kind == "light": S *= .96; V = np.minimum(255,V*1.02)
            elif kind == "olive": H=H*.86+2; S=S*.91+8; V=V*.86+6
            elif kind == "brown": H=H*.86+2; S=S*.89+12; V=V*.75+13
            elif kind == "deep": H=H*.85+2; S=S*.83+23; V=V*.56+17
            else: raise ValueError(kind)
        elif role in ("hair","brows","facial_hair"):
            if kind == "black":
                S *= .65
                V *= {"hair":.46,"brows":.56,"facial_hair":.67}[role]
            elif kind == "gray":
                S *= .04
                gain={"hair":1.17,"brows":1.13,"facial_hair":1.02}[role]
                cap={"hair":192,"brows":160,"facial_hair":136}[role]
                V=np.minimum(cap,V*gain+{"hair":8,"brows":3,"facial_hair":0}[role])
            elif kind == "blond":
                H[:]=17; S=np.clip(S*.53+35,0,255)
                gain={"hair":1.33,"brows":1.16,"facial_hair":1.06}[role]
                cap={"hair":213,"brows":165,"facial_hair":146}[role]
                V=np.minimum(cap,V*gain+4)
            elif kind == "copper":
                H[:]=8; S=S*1.04+8
                V=np.minimum(229,V*{"hair":1.18,"brows":1.11,"facial_hair":1.08}[role])
            else: raise ValueError(kind)
        elif role == "vest":
            if kind == "forest": H[:]=59; S=S*.57+23; V=V*.75+4
            elif kind == "blue": H[:]=109; S=S*.55+22; V=V*.82+4
            elif kind == "red": H[:]=3; S=S*.65+25; V=V*.81+4
            elif kind == "charcoal": S*=.12; V*=.88
            else: raise ValueError(kind)
        target=cv2.cvtColor(np.uint8(np.clip(cv2.merge([H,S,V]),0,255)),
                             cv2.COLOR_HSV2RGB).astype(np.float32)
        alpha=masks[role][:,:,None]
        out=out*(1-alpha)+target*alpha
    return np.uint8(np.clip(out,0,255))

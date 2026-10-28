"""Source-specific P1 edge refinement, candidate 3, NOT approved.

Run only after p1_mask_refinement_v2.refine_masks on a 1229x1536 male_09
original. The coordinates are hand-reviewed on the uploaded RGB master.
Never claim they transfer to another figure. Source bytes of the Git original
must still be compared to the user upload before approval.
"""
import cv2
import numpy as np
from p1_visual_tuning import region as poly
from p1_mask_refinement_v2 import recolor_v2


def refine_v3(src, old):
    h, w = src.shape[:2]
    if (w, h) != (1229, 1536):
        raise ValueError("P1 v3 supports only the 1229x1536 male_09 master")
    m = {key: old[key].astype(np.float32).copy()
         for key in ("skin", "hair", "brows", "shirt")}
    R, G, B = [src[:, :, i].astype(np.float32) for i in range(3)]
    H, S, V = cv2.split(cv2.cvtColor(src, cv2.COLOR_RGB2HSV))

    # Thin sideburns and side locks: polygons were adjusted against the
    # actual uploaded master and deliberately stop before the ears.
    left = poly((h, w), [(394,204),(470,211),(474,266),(477,297),
        (466,333),(461,367),(455,400),(437,419),(422,360),
        (406,329),(394,279)])
    right = poly((h, w), [(748,196),(831,196),(835,264),(822,316),
        (809,370),(787,386),(773,342),(783,270)])
    side = np.maximum(left, right)
    brown_ink = ((R < 201) & (G < 147) & (R > G * 1.09)
                 & (G > B * 1.04) & (S > 44) & (V >= 15))
    add_side = (side > .1) & brown_ink & (m["brows"] < .15)
    m["hair"] = np.maximum(m["hair"], cv2.GaussianBlur(
        add_side.astype(np.float32), (3, 3), .65))

    # Small anti-aliased fragments of *dark original hair ink* at the hairline.
    crown = poly((h, w), [(405,160),(759,163),(821,246),(823,330),
        (773,340),(735,264),(575,279),(460,294),(397,332)])
    near = cv2.dilate((m["hair"] > .25).astype(np.uint8),
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))) > 0
    ink_edge = ((crown > .1) & near & (R < 207) & (G < 145)
                & (R > G * 1.12) & (S > 48) & (V > 36))
    m["hair"] = np.maximum(m["hair"], cv2.GaussianBlur(
        ink_edge.astype(np.float32), (5, 5), .75) * .98)

    # Fill small pixel holes inside known eyebrow shapes. Neither eyelids nor
    # unrelated dark face outlines may become eyebrow colour by proximity.
    seed = (m["brows"] > .24).astype(np.uint8)
    closed = cv2.morphologyEx(seed, cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 5)))
    near_brow = cv2.dilate(seed,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))) > 0
    dark_brow = (R < 177) & (G < 126) & (V < 185) & (S > 35)
    add_brow = (closed > 0) & near_brow & dark_brow
    m["brows"] = np.maximum(m["brows"], cv2.GaussianBlur(
        add_brow.astype(np.float32), (3, 3), .6))

    # Recolour only very small skin-like highlights along the crown boundary.
    hairline = poly((h, w), [(460,170),(737,172),(773,208),
        (771,294),(450,294),(453,222)])
    near_hair = cv2.dilate((m["hair"] > .50).astype(np.uint8),
        np.ones((7, 7), np.uint8)) > 0
    warm = ((R > 185) & (G > 105) & (R > G * 1.15)
            & (G > B * 1.1) & (S > 52) & (V > 170))
    edge = ((hairline > .1) & near_hair & warm
            & (m["hair"] < .25) & (m["brows"] < .1))
    m["skin"][edge] = np.maximum(m["skin"][edge], .97)

    # Hair before eyebrows before skin before fabric. Keep low-alpha edge
    # feathering but never apply two strong (>35%) colour roles to one pixel.
    m["brows"] *= 1 - m["hair"]
    m["skin"] *= 1 - m["hair"]
    m["skin"] *= 1 - m["brows"]
    m["shirt"] *= 1 - m["skin"]
    m["shirt"] *= 1 - m["hair"]
    for winner, loser in (
        ("hair","brows"),("hair","skin"),("brows","skin"),
        ("skin","shirt"),("hair","shirt"),("brows","shirt")
    ):
        clash = (m[winner] > .35) & (m[loser] > .35)
        m[loser][clash] = np.minimum(m[loser][clash], .34)
    return {key: np.clip(value, 0, 1) for key, value in m.items()}


def recolor_v3(rgb, masks, skin="original", hair="original",
               shirt="original"):
    """Use v2 shadows; soften only overly bright scalp blonde/grey pixels.

    This palette remains experimental. Facial-brow and goatee transforms use
    the v2 proportions, not the scalp brightness adjustment.
    """
    out = recolor_v2(rgb, masks, skin=skin, hair=hair, shirt=shirt).astype(
        np.float32)
    if hair not in ("gray", "blond"):
        return out.astype(np.uint8)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    H, S, V = cv2.split(hsv)
    new_h, new_s, new_v = H.copy(), S.copy(), V.copy()
    old_h, old_s, old_v = H.copy(), S.copy(), V.copy()
    if hair == "gray":
        old_s *= .07
        old_v = np.minimum(227, old_v * 1.55 + 7)
        new_s *= .08
        new_v = np.minimum(201, new_v * 1.35 + 5)
    else:
        old_h[:] = 17
        old_s = np.clip(old_s * .48 + 38, 0, 255)
        old_v = np.minimum(237, old_v * 1.55 + 13)
        new_h[:] = 17
        new_s = np.clip(new_s * .50 + 37, 0, 255)
        new_v = np.minimum(215, new_v * 1.39 + 10)
    old_rgb = cv2.cvtColor(np.uint8(np.clip(
        cv2.merge([old_h, old_s, old_v]), 0, 255)),
        cv2.COLOR_HSV2RGB).astype(np.float32)
    new_rgb = cv2.cvtColor(np.uint8(np.clip(
        cv2.merge([new_h, new_s, new_v]), 0, 255)),
        cv2.COLOR_HSV2RGB).astype(np.float32)
    out += masks["hair"][:, :, None] * (new_rgb - old_rgb)
    return np.uint8(np.clip(out, 0, 255))

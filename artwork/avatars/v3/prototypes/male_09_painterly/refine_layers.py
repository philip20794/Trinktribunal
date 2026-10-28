#!/usr/bin/env python3
"""ART-04 painterly proof-of-concept. Nonproduction SVG source generator.

Read existing 8 semantic SVG layers from the previously committed technical test,
redraw eyes, brows and expression, add palettized organic pen/paint overlays.
This is *new painted geometry*, not a crop of the reference PNG.
"""
from __future__ import annotations
from pathlib import Path
import random
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'male_09'/'layers'
if not OLD.exists(): OLD=ROOT.parent/'trinktribunal_v3_art04_tech01'/'layers'
OUT=ROOT/'layers'
OUT.mkdir(exist_ok=True)
NS='http://www.w3.org/2000/svg'
ET.register_namespace('',NS)

# Full rewrite of the facial features. An intentionally unflattering,
# angry, lopsided caricature rather than the smiling geometric placeholder.
EXPRESSION='''
<!-- heavy irregular slanted eyebrows -->
<path fill="#432a26" stroke="#3a2724" stroke-width="3" d="M391 381 Q401 352 436 355 Q462 358 477 390 L470 404 Q434 387 394 399Z"/>
<path fill="#432a26" stroke="#3a2724" stroke-width="3" d="M554 389 Q566 360 596 353 Q623 347 651 365 L645 384 Q609 372 558 401Z"/>
<path fill="none" stroke="#7a4d35" stroke-width="2.6" opacity=".60" d="M402 376Q423 370 439 380M571 374Q607 356 623 371"/>
<!-- stretched half-lidded sclera, side-eye to viewer's right -->
<path fill="#f4e4d1" stroke="#69423b" stroke-width="5" d="M393 429 Q419 407 473 415 Q482 436 459 456 Q427 469 406 449 Q398 443 393 429Z"/>
<path fill="#f4e4d1" stroke="#69423b" stroke-width="5" d="M554 412 Q590 387 644 397 Q647 419 627 439 Q595 450 565 432Z"/>
<!-- irises shifted right to make the expression suspicious -->
<path fill="#513d32" d="M442 419 Q460 421 458 457 Q444 461 438 451 Q432 428 442 419Z"/>
<path fill="#513d32" d="M616 395 Q632 398 627 436 Q613 441 608 430 Q605 407 616 395Z"/>
<path fill="#211f22" d="M450 423Q457 431 454 450Q450 454 446 448Q442 436 446 425ZM623 399Q629 409 624 430Q620 433 618 425Q616 410 620 401Z"/>
<path fill="#fff7df" opacity=".93" d="M450 425Q454 423 455 430Q452 435 449 432ZM619 405Q621 402 624 406Q624 411 620 411Z"/>
<!-- thick shaded half-lids hide the upper eye white and pupils -->
<path data-palette="skin.base" fill="#edb08d" d="M393 428Q426 409 473 418L466 435Q429 427 394 441Z M554 412Q601 389 644 398L635 416Q590 409 555 425Z"/>
<path data-palette="skin.shadow" fill="#bb6b56" opacity=".36" d="M399 428Q424 416 468 422L462 431Q419 429 401 437Z M559 410Q606 394 639 400L630 411Q592 407 559 419Z"/>
<!-- heavy arcing lids cross the pupils, asymmetrical eye bags -->
<path fill="none" stroke="#3b2927" stroke-width="8" d="M391 426Q429 401 473 418M552 414Q599 386 645 398"/>
<path fill="none" stroke="#94564c" stroke-width="5" opacity=".72" d="M404 457Q428 477 466 456M560 443Q601 463 636 435"/>
<path fill="none" stroke="#a36657" stroke-width="2.5" opacity=".64" d="M401 468Q431 491 464 473M567 454Q604 467 633 444"/>
<!-- angular downturned sneer, one tooth on the raised corner -->
<path fill="#773d3a" stroke="#60352f" stroke-width="5" d="M455 609 Q493 586 531 589 Q554 591 571 577 Q580 589 580 602 Q558 610 552 623 Q531 646 498 645 Q472 635 455 609Z"/>
<path fill="#412b2e" d="M463 607Q497 600 531 604Q561 598 575 592Q565 609 551 618Q531 630 503 627Q482 624 463 607Z"/>
<path fill="#f3e0c7" d="M543 602Q556 596 572 594L564 610Q552 615 543 611Z"/>
<path fill="none" stroke="#663932" stroke-width="4" d="M450 609Q455 605 461 606M575 579Q581 571 589 576"/>
<path fill="none" stroke="#a55e51" stroke-width="3" opacity=".67" d="M484 654Q511 665 535 652M548 627Q556 629 563 625"/>
<!-- tiny moustache stubble on upper lip -->
<g stroke="#754b40" stroke-width="2" opacity=".52"><path d="M478 582l3 5M488 579l3 6M503 578l2 5M525 578l2 5M539 578l2 4M551 576l2 4"/></g>
'''

def path_element(role: str, d: str, width: float, opacity:float, fill:bool=False)->str:
    col={'skin.shadow':'#bb6b56','skin.highlight':'#ffcfaa','skin.blush':'#da7869',
         'hair.light':'#986646','hair.shadow':'#30202a',
         'cloth.light':'#90649a','cloth.shadow':'#422a50'}[role]
    if fill:
        return f'<path data-palette="{role}" fill="{col}" opacity="{opacity:.2f}" d="{d}"/>'
    return f'<path data-palette="{role}" stroke="{col}" fill="none" stroke-width="{width:.2f}" opacity="{opacity:.2f}" d="{d}"/>'

rng=random.Random(28062026)
def organic_strokes(xr,yr,n,role,w_rng=(.7,2.3),length_rng=(3,17),opacity_rng=(.12,.35),angle=0.0):
    pieces=[]
    for _ in range(n):
        x=rng.uniform(*xr);y=rng.uniform(*yr)
        length=rng.uniform(*length_rng)
        dx=rng.uniform(-.6,.6)*length+angle*length
        dy=length*rng.uniform(.5,1.)
        bend=rng.uniform(-4,4)
        d=f'M{x:.1f} {y:.1f}q{dx*.25+bend:.1f} {dy*.4:.1f} {dx:.1f} {dy:.1f}'
        pieces.append(path_element(role,d,rng.uniform(*w_rng),rng.uniform(*opacity_rng)))
    return '\n'.join(pieces)

# Painterly lines are constrained to the specific facial areas, clothing and hair regions.
DETAILS={}
DETAILS['01_body_skin']='''
<!-- anatomically irregular collarbone/clavicle shading -->
<path data-palette="skin.shadow" fill="#bb6b56" opacity=".28" d="M453 748Q481 760 500 793L478 781Q463 773 453 748ZM562 748Q549 770 529 788Q558 784 570 763Z"/>
<path fill="none" stroke="#a95a49" stroke-width="2.6" opacity=".60" d="M459 744Q476 759 493 767M547 764Q564 753 569 745"/>
'''
DETAILS['02_clothes_shirt']='''
<!-- uneven hand-painted fabric folds, individual highlights -->
<path data-palette="cloth.shadow" fill="#422a50" opacity=".40" d="M276 834Q245 914 266 969L286 1003Q268 928 276 834ZM709 844Q741 910 728 986L716 1027Q728 937 709 844Z"/>
<path data-palette="cloth.light" fill="#90649a" opacity=".22" d="M342 842Q389 876 430 882Q395 866 377 847ZM612 839Q647 845 679 869Q657 837 618 825Z"/>
<path fill="none" stroke="#b895a5" stroke-width="2" opacity=".30" d="M192 860q35 -23 71 -24M295 902q16 29 18 63M718 1172q12 27 12 52M333 1164q38 18 56 25"/>
'''
DETAILS['03_arms_hands_back']='''
<path data-palette="skin.highlight" fill="#ffcfaa" opacity=".29" d="M144 931Q116 1014 169 1104L157 1097Q116 1043 127 977Z"/>
<path data-palette="skin.shadow" fill="#bb6b56" opacity=".25" d="M878 931Q913 1023 855 1114L875 1092Q908 1044 893 979Z"/>
<path fill="none" stroke="#7e483c" stroke-width="2" opacity=".45" d="M143 1020q3 9 9 14M155 1056q5 9 9 14M871 1022q-5 12 -9 15"/>
'''
DETAILS['04_head_face']='''
<!-- irregular blush patches, brow/nose shadows and handmade fine anatomy -->
<path data-palette="skin.blush" fill="#da7869" opacity=".16" d="M378 467Q411 461 462 489Q449 532 415 541Q386 526 378 467ZM574 474Q610 464 639 476Q634 527 594 536Z"/>
<path data-palette="skin.highlight" fill="#ffcfaa" opacity=".25" d="M396 306Q408 287 445 277Q410 331 412 393L403 451Q390 397 396 306Z"/>
<path data-palette="skin.shadow" fill="#bb6b56" opacity=".16" d="M559 349Q606 363 616 424Q613 449 599 476Q592 410 559 349Z"/>
<path fill="none" stroke="#864c3b" stroke-width="2" opacity=".35" d="M420 315q21 -11 43 -6M400 349q-5 24 0 45M592 318q21 13 31 29M403 557q12 28 29 41M594 589q-14 27 -25 35M504 655q15 8 30 1"/>
<path data-palette="skin.highlight" fill="#ffcfaa" opacity=".36" d="M478 524Q494 514 507 526Q495 531 478 533Z"/>
<path fill="none" stroke="#8a4a3c" stroke-width="2" opacity=".42" d="M475 515q-12 13 -11 23M558 528q9 10 7 21M485 563q17 9 30 5"/>
'''
DETAILS['05_eyes_brows_mouth']='''
<!-- eye bags & brows were replaced by an organically asymmetric expression -->
'''
DETAILS['06_hair_front']='''
<!-- loose hand-drawn flyaway strands break the angular SVG silhouette -->
<path fill="none" data-palette="hair.shadow" stroke="#30202a" opacity=".70" stroke-width="3" d="M340 267Q373 238 424 243M373 249Q354 230 330 220M408 221Q387 177 388 162M444 205Q437 173 420 161M503 169Q496 138 512 108M545 189Q574 154 572 137M590 210Q631 168 652 167M646 252Q683 240 697 215M421 276Q393 281 380 305"/>
<path fill="none" data-palette="hair.light" stroke="#986646" opacity=".67" stroke-width="2" d="M370 270Q411 260 439 268M434 196Q468 244 485 249M498 146Q518 194 511 233M564 171Q552 202 539 233M595 203Q574 228 555 240M641 240Q614 248 596 258"/> 
<!-- sun-catching painterly bunches of directional hair -->
<path data-palette="hair.shadow" fill="#30202a" opacity=".48" d="M366 288Q417 262 464 260Q407 278 383 323Z"/>
<path data-palette="hair.light" fill="#986646" opacity=".43" d="M433 223Q456 249 477 269L451 258ZM506 160Q525 211 520 241Q527 207 533 193Z"/>
<path fill="none" stroke="#2e2226" stroke-width="3" opacity=".73" d="M388 279Q412 282 443 267M461 240Q473 267 489 274M541 256Q572 225 597 207M568 268Q618 246 647 254"/>
'''
DETAILS['07_beard_goatee']='''
<path data-palette="hair.light" fill="#986646" opacity=".33" d="M511 668Q521 667 526 673L519 693Z"/>
<path fill="none" stroke="#38282a" stroke-width="1.5" opacity=".6" d="M498 672q3 12 9 18M536 675q-6 14 -9 22M512 686q4 12 7 24"/>
'''
DETAILS['08_grip_fingers_front']='''
<!-- short fingernail shapes, knuckles and wrinkles -->
<path data-palette="skin.highlight" fill="#ffcfaa" opacity=".67" d="M173 967Q185 966 196 975Q193 985 179 982Z M164 1019Q178 1017 190 1028Q187 1038 173 1034Z M166 1068Q179 1066 190 1077Q185 1087 173 1083Z M851 966Q839 963 826 975Q829 986 843 982Z M862 1017Q847 1015 836 1027Q841 1038 853 1033Z M858 1067Q845 1064 834 1078Q838 1086 851 1083Z"/>
<path fill="none" stroke="#995646" opacity=".55" stroke-width="2" d="M199 983q10 6 14 5M194 1036q13 7 19 6M196 1086q10 5 17 6M825 982q-9 5 -15 5M825 1038q-10 5 -17 6M825 1086q-11 6 -18 6"/>
'''
# Clipped pigment marks prevent pen strokes from spilling out of the character.
# Clip only the targeted base shape(s), preserving transparent per-layer pixels.
ZONES={
 '01_body_skin': [('skin.base',(449,562),(655,771),180,'skin.shadow')],
 '02_clothes_shirt':[('cloth.base',(278,739),(855,1231),350,'cloth.shadow'),('cloth.base',(294,728),(810,1210),240,'cloth.light')],
 '03_arms_hands_back':[('skin.base',(131,230),(925,1120),90,'skin.shadow')],
 '04_head_face':[('skin.base',(393,647),(330,669),330,'skin.shadow'),('skin.base',(401,636),(350,640),280,'skin.highlight'),('skin.base',(395,638),(456,600),130,'skin.blush')],
 '06_hair_front':[('hair.base',(380,660),(205,290),220,'hair.light'),('hair.base',(395,646),(205,287),180,'hair.shadow')],
 '08_grip_fingers_front':[('skin.base',(170,870),(965,1110),200,'skin.shadow')],
}

def add_details(svg,key):
    r=ET.fromstring(svg)
    if key=='05_eyes_brows_mouth':
        # Retain nothing of the overly symmetric eyes and smiling mouth.
        for child in list(r):r.remove(child)
        grp=ET.fromstring('<g xmlns="http://www.w3.org/2000/svg" stroke-linecap="round" stroke-linejoin="round">'+EXPRESSION+'</g>')
        r.append(grp)
    details=DETAILS.get(key,'')
    if details:
        grp=ET.fromstring('<g xmlns="http://www.w3.org/2000/svg" stroke-linecap="round" stroke-linejoin="round">'+details+'</g>')
        r.append(grp)
    if key in ZONES:
        base_paths=[]
        for el in r.iter():
            if el.attrib.get('data-palette','') in {row[0] for row in ZONES[key]} and el.tag.endswith('path'):
                base_paths.append(el)
        defs=ET.SubElement(r, f'{{{NS}}}defs')
        for i,(role,xr,yr,n,shade_role) in enumerate(ZONES[key]):
            clip_id='pigment_'+key+'_'+str(i)
            clip=ET.SubElement(defs,f'{{{NS}}}clipPath',{'id':clip_id,'clipPathUnits':'userSpaceOnUse'})
            for b in base_paths:
                if b.attrib.get('data-palette')==role:
                    ET.SubElement(clip,f'{{{NS}}}path',{'d':b.attrib['d']})
            # Big randomized samples are clipped to the color region so skin stays skin and fabric stays fabric.
            g=ET.SubElement(r,f'{{{NS}}}g',{'clip-path':f'url(#{clip_id})'})
            data=organic_strokes(xr,(yr[0],yr[1]),n,shade_role,
                 w_rng=(.8,2.3) if 'cloth' in role else (.5,1.65),
                 length_rng=(3,22) if 'cloth' in role else (2,10),
                 opacity_rng=(.07,.23) if 'cloth' in role else (.07,.19),
                 angle=.6 if 'hair' in role else .0)
            wrap=ET.fromstring('<g xmlns="http://www.w3.org/2000/svg">'+data+'</g>')
            for el in list(wrap):g.append(el)
    return ET.tostring(r,encoding='unicode')

if __name__=='__main__':
    for src in sorted(OLD.glob('*.svg')):
        key=src.stem
        dst=OUT/src.name
        svg=add_details(src.read_text(encoding='utf-8'),key)
        ET.fromstring(svg)
        dst.write_text(svg,encoding='utf-8')
        print(dst.name,len(svg),'bytes')
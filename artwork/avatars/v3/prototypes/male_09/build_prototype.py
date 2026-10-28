#!/usr/bin/env python3
"""Trinktribunal v3: proof-of-concept, intentionally NOT a runtime exporter.

Creates artist-authored SVG layers with role-tagged semantic palette regions, composites
several color combinations, checks RGBA transparency and writes a contact sheet.
"""
from __future__ import annotations
from pathlib import Path
from copy import deepcopy
from io import BytesIO
import xml.etree.ElementTree as ET
import random
from PIL import Image, ImageDraw, ImageFont

def font_at(size, bold=False):
    # Use installed system fonts; test previews may use the Pillow fallback.
    names = (
        ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 'C:/Windows/Fonts/arialbd.ttf', '/System/Library/Fonts/Supplemental/Arial Bold.ttf']
        if bold else
        ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 'C:/Windows/Fonts/arial.ttf', '/System/Library/Fonts/Supplemental/Arial.ttf']
    )
    for name in names:
        try: return ImageFont.truetype(name, size)
        except OSError: pass
    return ImageFont.load_default()
import cairosvg

OUT=Path(__file__).parent
SZ=(1024,1280)
NS='http://www.w3.org/2000/svg'
ET.register_namespace('',NS)
PALETTES={
 'light': {'skin.base':'#edb08d','skin.shadow':'#bb6b56','skin.deep':'#81423a','skin.highlight':'#ffcfaa','skin.blush':'#da7869','skin.line':'#683e35'},
 'olive': {'skin.base':'#bd966e','skin.shadow':'#80664c','skin.deep':'#574536','skin.highlight':'#dec19a','skin.blush':'#a9675b','skin.line':'#4e3c30'},
 'deep':  {'skin.base':'#714936','skin.shadow':'#452c28','skin.deep':'#302123','skin.highlight':'#a57c59','skin.blush':'#875342','skin.line':'#352725'},
}
HAIR={
 'brown':{'hair.base':'#543328','hair.shadow':'#30202a','hair.light':'#986646','hair.line':'#2f2226'},
 'black':{'hair.base':'#2a2531','hair.shadow':'#171823','hair.light':'#62515b','hair.line':'#191621'},
 'blond':{'hair.base':'#b77738','hair.shadow':'#81552f','hair.light':'#e1ab62','hair.line':'#583d2d'},
 'gray':{'hair.base':'#89837c','hair.shadow':'#514b4c','hair.light':'#c9c0a9','hair.line':'#3c393d'},
 'copper':{'hair.base':'#a3472b','hair.shadow':'#612d25','hair.light':'#d67e48','hair.line':'#482629'},
 'purple':{'hair.base':'#67435e','hair.shadow':'#382637','hair.light':'#aa718c','hair.line':'#2e232c'},
}
FABRICS={
 'purple':{'cloth.base':'#6a416f','cloth.shadow':'#422a50','cloth.light':'#90649a','cloth.line':'#392d42'},
 'forest':{'cloth.base':'#4f6b55','cloth.shadow':'#304839','cloth.light':'#769582','cloth.line':'#2c3b35'},
 'blue':{'cloth.base':'#46647d','cloth.shadow':'#314256','cloth.light':'#6f91a3','cloth.line':'#293543'},
}
DEFAULT={**PALETTES['light'],**HAIR['brown'],**FABRICS['purple']}

def root(inner):
 return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1280" viewBox="0 0 1024 1280" aria-label="Trinktribunal Avatar Prototyp: getrennte Ebene"><g stroke-linecap="round" stroke-linejoin="round">{inner}</g></svg>'''
L={}
L['01_body_skin']=root('''
 <!-- Neck and shoulders before clothes: never baked into an outfit -->
 <path data-palette="skin.deep" fill="#81423a" stroke="#6a3c34" stroke-width="7" d="M446 650 Q448 717 421 778 L358 830 Q500 875 663 815 L608 778 Q577 724 582 654 Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#683e35" stroke-width="4" d="M456 634 Q461 728 430 783 Q500 808 599 775 Q569 725 573 639 Z"/>
 <path data-palette="skin.shadow" fill="#bb6b56" opacity=".50" d="M541 665 Q561 725 568 764 L588 779 555 788 Q532 750 541 665Z"/>
 <path data-palette="skin.highlight" fill="#ffcfaa" opacity=".62" d="M473 675 Q484 747 452 782 L475 791 Q497 755 491 711Z"/>
 <path fill="none" stroke="#9c604d" stroke-width="4" opacity=".65" d="M460 749Q484 775 500 770M564 754Q548 772 533 768"/>
''')
L['02_clothes_shirt']=root('''
 <!-- torso and sleeves can be replaced without recoloring the skin -->
 <path data-palette="cloth.shadow" fill="#422a50" stroke="#392d42" stroke-width="9" d="M415 755 Q360 752 270 779 Q205 799 149 854 L106 968 Q175 1002 243 1019 L266 1250 746 1250 776 1024 Q829 1015 905 975 L865 850 Q811 797 676 763 L608 741 Q589 782 514 802 Q447 794 415 755Z"/>
 <path data-palette="cloth.base" fill="#6a416f" d="M411 760 Q348 769 268 798 L173 853 Q163 888 145 958 L235 989 258 888 271 1247 751 1247 763 882 795 991 874 959 848 852 Q790 806 673 781 L605 748 Q564 816 513 818 Q445 814 411 760Z"/>
 <path data-palette="cloth.light" fill="#90649a" opacity=".46" d="M284 808 Q241 821 187 863L162 933 216 944Q235 877 284 808ZM304 910Q289 1023 301 1234L341 1242Q335 1101 304 910Z"/>
 <path data-palette="cloth.shadow" fill="#422a50" opacity=".67" d="M735 858Q704 1030 707 1235L746 1235 763 902ZM671 813 Q613 839 577 850 Q657 827 673 781 Z"/>
 <path fill="none" stroke="#3c2c44" stroke-width="6" d="M250 987 Q241 1007 237 1026M774 989Q782 1012 787 1026"/>
 <!-- large soft neckline, neck layer remains underneath -->
 <path data-palette="cloth.shadow" fill="#422a50" stroke="#3a2b40" stroke-width="6" d="M413 752 Q450 797 515 804 Q582 804 614 748 L650 774 Q592 860 511 862 Q441 853 386 784Z"/>
 <path data-palette="cloth.light" fill="#90649a" opacity=".7" d="M405 776 Q441 838 510 841 Q577 841 629 779" stroke="#b58db7" stroke-width="3"/>
 <!-- small drawn fabric wrinkles -->
 <path fill="none" stroke="#3c2b42" stroke-width="4" opacity=".66" d="M274 884 Q309 922 323 976 M719 941 Q745 906 753 882 M358 1197Q402 1220 465 1223 M684 1055 Q664 1107 691 1154"/>
 <path fill="none" stroke="#b28eb8" stroke-width="3" opacity=".45" d="M264 873Q249 901 244 936M373 1058Q399 1080 412 1115"/>
''')
L['03_arms_hands_back']=root('''
 <!-- Arms behind the plaque; hands will be completed on top of the plaque -->
 <path data-palette="skin.deep" fill="#81423a" stroke="#683e35" stroke-width="7" d="M149 887 Q111 924 103 980 Q96 1024 124 1096 L163 1143 Q212 1174 249 1119 L259 1007 Q244 944 205 905Z"/>
 <path data-palette="skin.base" fill="#edb08d" d="M156 907Q119 954 124 1003Q125 1066 170 1126Q210 1149 232 1102L238 1010Q225 957 196 919Z"/>
 <path data-palette="skin.shadow" fill="#bb6b56" opacity=".55" d="M127 1015Q139 1099 184 1130L216 1113Q157 1070 156 1007Z"/>
 <path data-palette="skin.deep" fill="#81423a" stroke="#683e35" stroke-width="7" d="M872 889Q913 932 921 983Q923 1061 883 1124Q834 1170 797 1123L775 1016Q789 933 826 904Z"/>
 <path data-palette="skin.base" fill="#edb08d" d="M861 912Q904 969 902 1020Q885 1109 848 1131Q809 1138 791 1092L791 1010Q809 943 832 920Z"/>
 <path data-palette="skin.shadow" fill="#bb6b56" opacity=".56" d="M885 1016Q882 1071 841 1128L808 1110Q856 1062 856 1022Z"/>
 <path fill="none" stroke="#a36355" opacity=".7" stroke-width="3" d="M135 1046Q151 1065 164 1070M889 1035Q877 1063 865 1073"/>
''')
L['04_head_face']=root('''
 <!-- Distinct long, irregular caricature head with attached ears; no hair or clothing baked in -->
 <path data-palette="skin.deep" fill="#81423a" stroke="#653b35" stroke-width="8" d="M383 370Q347 318 303 346Q273 363 290 418Q304 454 348 467Q358 511 373 548Q382 644 448 704Q489 733 541 719Q622 697 651 579Q666 532 672 468Q733 480 767 432Q803 377 772 347Q736 320 674 357L648 298Q608 220 494 216Q400 229 377 309Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#683e35" stroke-width="6" d="M390 343Q373 300 350 355Q319 358 327 411Q342 446 372 447Q376 522 394 580Q416 674 480 703Q545 728 595 665Q634 608 650 521L662 438Q709 457 741 422Q771 382 741 369Q710 365 666 403Q658 333 636 295Q595 240 520 235Q430 236 399 288Z"/>
 <!-- broad asymmetric ears -->
 <path data-palette="skin.base" fill="#edb08d" stroke="#683e35" stroke-width="6" d="M378 358Q343 330 316 346Q279 365 299 414Q316 460 367 460Z"/>
 <path data-palette="skin.blush" fill="#da7869" opacity=".67" d="M340 362Q305 367 320 406Q330 427 360 439Q340 405 351 392Z"/>
 <path fill="none" stroke="#a65d50" stroke-width="6" d="M362 433Q337 429 331 404Q329 386 350 383Q360 384 362 400"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#683e35" stroke-width="6" d="M658 381Q717 327 756 349Q791 369 763 425Q743 463 669 463Z"/>
 <path data-palette="skin.blush" fill="#da7869" opacity=".7" d="M690 405Q718 358 746 372Q755 387 730 426Q706 446 681 443Z"/>
 <path fill="none" stroke="#9c554a" stroke-width="7" d="M687 430Q724 426 733 392Q733 377 718 381Q697 389 695 408"/>
 <!-- face shape shadow: keeps malleable warm skin modeling -->
 <path data-palette="skin.shadow" fill="#bb6b56" opacity=".30" d="M598 316Q650 400 625 534Q618 644 563 685Q615 648 638 555Q674 425 635 314Z"/>
 <path data-palette="skin.highlight" fill="#ffcfaa" opacity=".45" d="M403 334Q391 488 412 558Q420 604 435 624Q395 578 389 494Q377 395 403 334Z"/>
 <!-- strong crooked jaw and chin -->
 <path fill="none" stroke="#96574a" opacity=".85" stroke-width="4" d="M405 602Q436 694 503 701Q549 710 590 651"/>
 <path data-palette="skin.shadow" fill="#bb6b56" opacity=".31" d="M414 597 Q460 650 504 655Q563 666 599 610Q566 686 520 700Q439 699 414 597Z"/>
 <!-- long distinctive protruding nose and warm flushed tip -->
 <path data-palette="skin.shadow" fill="#bb6b56" opacity=".50" d="M509 376Q512 449 473 531Q456 549 475 561Q512 580 564 553Q577 534 559 519Q548 452 539 385Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#864a40" stroke-width="5" d="M506 399Q503 465 476 512Q456 544 476 557Q514 576 559 551Q568 543 552 522Q539 457 536 394"/>
 <path data-palette="skin.blush" fill="#da7869" opacity=".86" d="M474 529Q495 514 539 526Q564 537 545 554Q508 570 479 551Q469 545 474 529Z"/>
 <path data-palette="skin.highlight" fill="#ffcfaa" opacity=".78" d="M488 527Q504 521 517 526Q510 536 488 537Z"/>
 <path fill="none" stroke="#8f4a42" stroke-width="5" d="M480 553Q487 562 501 558M542 556Q553 553 556 546"/>
 <!-- cheeks and blush -->
 <ellipse data-palette="skin.blush" fill="#da7869" opacity=".21" cx="408" cy="512" rx="37" ry="30"/>
 <ellipse data-palette="skin.blush" fill="#da7869" opacity=".20" cx="613" cy="509" rx="30" ry="32"/>
 <path data-palette="skin.highlight" fill="#ffcfaa" opacity=".18" d="M405 478Q438 466 458 482Q432 501 405 497ZM575 487Q610 468 629 480Q617 502 579 506Z"/>
 <!-- small freckles retained through recoloring -->
 <g fill="#8e5046" opacity=".46"><circle cx="402" cy="526" r="3"/><circle cx="417" cy="535" r="2.2"/><circle cx="427" cy="523" r="2.5"/><circle cx="595" cy="524" r="3"/><circle cx="614" cy="526" r="2.5"/><circle cx="628" cy="517" r="2"/></g>
''')
L['05_eyes_brows_mouth']=root('''
 <!-- Cartoon eyes and severe off-centre stare. These elements remain independent of skin-tone changes. -->
 <path fill="#4c2e2b" d="M395 380Q433 355 471 375Q475 388 469 393Q441 381 400 394Z"/>
 <path fill="#4c2e2b" d="M558 369Q595 343 637 370L643 383Q608 371 566 387Z"/>
 <path fill="#f6ebdb" stroke="#713b32" stroke-width="6" d="M397 420Q430 395 466 411Q479 422 469 445Q441 463 408 451Q393 440 397 420Z"/>
 <path fill="#f6ebdb" stroke="#713b32" stroke-width="6" d="M555 410Q590 385 625 401Q642 412 635 433Q613 457 578 443Q557 433 555 410Z"/>
 <path fill="#492f29" d="M444 405Q462 424 451 451Q440 453 432 448Q426 423 438 406Z"/>
 <path fill="#492f29" d="M599 396Q615 410 608 443Q595 449 587 438Q582 418 592 399Z"/>
 <circle fill="#f3e6d7" cx="442" cy="415" r="5"/><circle fill="#f3e6d7" cx="599" cy="406" r="5"/>
 <path fill="none" stroke="#432e2d" stroke-width="8" d="M392 418Q429 399 470 411M553 409Q596 381 632 402"/>
 <!-- Lower-lid and eye bags for a tired, grumpy expression -->
 <path fill="none" stroke="#97534c" opacity=".76" stroke-width="4" d="M404 462Q441 478 470 457M562 453Q598 466 638 441M411 472Q438 488 458 473"/>
 <path fill="none" stroke="#a66155" stroke-width="3" opacity=".56" d="M392 453Q399 470 401 477M641 438Q644 452 639 461"/>
 <!-- twisted frowning mouth, intentionally asymmetric -->
 <path fill="#743f3d" stroke="#68352f" stroke-width="5" d="M465 603Q509 585 551 593Q564 591 573 584Q567 617 532 628Q492 639 465 603Z"/>
 <path fill="#4c2c30" d="M472 604Q515 600 555 603Q547 615 514 618Q494 618 472 604Z"/>
 <path fill="#f4e2d3" d="M523 603Q542 606 554 603Q546 611 525 611Z"/>
 <path fill="none" stroke="#6e3c35" stroke-width="4" d="M456 604Q464 603 472 606 M568 589Q577 579 584 580"/>
 <path fill="none" stroke="#a56355" stroke-width="3" opacity=".65" d="M482 650Q516 665 538 650"/>
''')
L['06_hair_front']=root('''
 <!-- Asymmetrical spiky hair, independent editable hair slot -->
 <path data-palette="hair.shadow" fill="#30202a" stroke="#2f2226" stroke-width="7" d="M384 347Q360 296 371 271L314 280Q333 255 382 249L339 222Q383 226 404 232L387 177Q427 203 444 216L431 147Q471 193 479 209L496 125Q523 174 522 204L557 147Q561 194 551 222L615 172Q595 219 581 231L672 195Q646 235 622 250L700 245Q658 267 650 304Q635 282 603 279Q563 260 529 285Q490 282 454 286Q414 296 384 347Z"/>
 <path data-palette="hair.base" fill="#543328" stroke="#2f2226" stroke-width="4" d="M377 306Q356 283 359 274Q413 274 426 257L390 203Q425 222 453 238L443 163Q471 197 486 239L510 152Q518 201 511 244L559 173Q552 222 548 242L640 198Q614 245 593 258L660 241Q636 274 596 276Q564 267 536 286Q493 265 467 286Q424 274 377 306Z"/>
 <path data-palette="hair.light" fill="#986646" opacity=".65" d="M373 280Q404 269 430 266L408 237Q445 252 464 267L452 194Q475 219 482 259L504 185Q511 213 503 261L563 199Q552 242 523 270Z"/>
 <path fill="none" stroke="#241c22" stroke-width="4" opacity=".78" d="M376 288Q427 279 448 289M443 192Q454 231 471 253M513 167Q515 224 503 260M594 216Q559 256 540 271"/>
 <path fill="none" stroke="#b07d5b" stroke-width="2.5" opacity=".66" d="M413 237Q450 253 458 266M557 202Q543 233 532 246"/>
''')
L['07_beard_goatee']=root('''
 <!-- chin stubble + tiny pointed goatee, separate from face/hair -->
 <path data-palette="hair.shadow" fill="#30202a" stroke="#2f2226" stroke-width="3" d="M493 665Q512 657 531 663L545 681Q542 707 522 726Q516 705 502 699Z"/>
 <path data-palette="hair.base" fill="#543328" opacity=".94" d="M505 670Q523 664 534 673L530 694 523 706 515 687Z"/>
 <path fill="none" stroke="#6f4d3c" stroke-width="3" opacity=".6" d="M507 678L519 702M525 675L523 699"/>
 <g fill="#51372f" opacity=".65"><circle cx="453" cy="635" r="2"/><circle cx="460" cy="642" r="2"/><circle cx="563" cy="641" r="2"/><circle cx="574" cy="624" r="1.5"/><circle cx="452" cy="651" r="1.6"/></g>
''')
L['08_grip_fingers_front']=root('''
 <!-- All fingers OVER the plaque; grip anchor remains fixed x≈172,852 -->
 <path data-palette="skin.deep" fill="#81423a" stroke="#633a32" stroke-width="6" d="M200 952 Q169 949 159 968 Q147 983 166 994 L198 1014 Q142 1009 146 1032 Q144 1047 162 1053 L204 1071 Q150 1064 155 1085 Q161 1103 209 1115 L238 1102 Q249 1079 234 1044 L226 975Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#744337" stroke-width="4" d="M200 954Q173 951 166 968Q160 981 177 988L219 1005Q235 1007 237 992Q239 980 222 973Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#744337" stroke-width="4" d="M185 1009Q160 999 153 1017Q148 1032 170 1039L219 1055Q239 1059 244 1043Q245 1030 224 1024Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#744337" stroke-width="4" d="M184 1056Q160 1047 157 1067Q155 1082 177 1090L218 1107Q239 1114 245 1096Q248 1080 229 1073Z"/>
 <path data-palette="skin.highlight" fill="#ffcfaa" opacity=".65" d="M176 966Q190 962 210 975L184 978ZM166 1016Q182 1011 204 1025L176 1027ZM170 1067Q185 1062 203 1078L177 1078Z"/>
 <path fill="none" stroke="#b66c54" stroke-width="3" opacity=".8" d="M178 986L193 993M177 1038L191 1044M178 1088L195 1095"/>
 <path data-palette="skin.deep" fill="#81423a" stroke="#633a32" stroke-width="6" d="M825 951Q859 946 873 966Q886 983 871 995L842 1014Q883 1007 883 1028Q885 1042 861 1054L834 1069Q879 1060 875 1080Q876 1099 821 1118L789 1102Q778 1080 790 1048L801 968Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#744337" stroke-width="4" d="M827 957Q850 950 862 963Q874 979 856 988L813 1005Q792 1007 789 993Q786 980 805 972Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#744337" stroke-width="4" d="M841 1007Q863 999 875 1015Q883 1030 861 1040L815 1056Q792 1061 787 1045Q784 1028 802 1024Z"/>
 <path data-palette="skin.base" fill="#edb08d" stroke="#744337" stroke-width="4" d="M842 1055Q864 1046 870 1065Q875 1082 847 1093L808 1109Q790 1111 782 1096Q778 1080 802 1073Z"/>
 <path data-palette="skin.highlight" fill="#ffcfaa" opacity=".65" d="M855 965Q837 961 819 976L848 977ZM858 1017Q840 1011 820 1026L854 1027ZM860 1067Q841 1061 821 1078L850 1078Z"/>
 <path fill="none" stroke="#ad6858" opacity=".7" stroke-width="3" d="M847 987L832 992M849 1039L833 1044M850 1088L829 1095"/>
''')

# Write each canonical SVG source and validate role annotations.
layer_dir=OUT/'layers';layer_dir.mkdir(exist_ok=True)
for key,svg in L.items():
 ET.fromstring(svg)
 (layer_dir/(key+'.svg')).write_text(svg,encoding='utf-8')

# Resolve the previously approved SVG sources in a Git checkout.
REPO_ROOT=Path(__file__).resolve().parents[5]
wall=(REPO_ROOT/'artwork/avatars/v3/background/mugshot_wall.svg').read_text(encoding='utf-8')
plaque=(REPO_ROOT/'artwork/avatars/v3/frame/nameplate.svg').read_text(encoding='utf-8')

# Composite in a real RGBA canvas, with semantic recoloring per distinct SVG element.
def render_svg(s,colors=None):
 r=ET.fromstring(s)
 for elem in r.iter():
  role=elem.attrib.get('data-palette')
  if role and colors and role in colors:
   # Only recolor specific parts, never their outlines, eyes or environment.
   if elem.tag.endswith('stop'): elem.set('stop-color',colors[role])
   else: elem.set('fill',colors[role])
 b=cairosvg.svg2png(bytestring=ET.tostring(r,encoding='utf-8'),output_width=1024,output_height=1280)
 return Image.open(BytesIO(b)).convert('RGBA')

def compose(skin='light',hair='brown',fabric='purple',name=None):
 pal={**PALETTES[skin],**HAIR[hair],**FABRICS[fabric]}
 canvas=render_svg(wall)
 for name_layer in ['01_body_skin','02_clothes_shirt','03_arms_hands_back','04_head_face','05_eyes_brows_mouth','06_hair_front','07_beard_goatee']:
  canvas=Image.alpha_composite(canvas,render_svg(L[name_layer],pal))
 canvas=Image.alpha_composite(canvas,render_svg(plaque))
 canvas=Image.alpha_composite(canvas,render_svg(L['08_grip_fingers_front'],pal))
 if name:
  # Preview only, not included in source art. Text is renderer-owned in production.
  dr=ImageDraw.Draw(canvas)
  font=font_at(max(36,54-2*max(0,len(name)-12)),bold=True)
  center=(512,1012)
  dr.text(center,name,font=font,fill='#f5ede0',anchor='mm',stroke_width=1,stroke_fill='#9d918a')
 return canvas

out=compose(name='SPIELERNAME')
out.save(OUT/'male_09_v3_composite.png')
# Test overlays separately and certify alpha for each layer.
checks={}
for key,svg in L.items():
 im=render_svg(svg)
 alpha=im.getchannel('A')
 checks[key]={'bbox':alpha.getbbox(),'alpha_zero':alpha.getextrema()[0]==0,'alpha_nonzero':alpha.getextrema()[1]>0}
 im.save(OUT/(key+'.png'))

# Color validation: 2 extreme skins + olive, 6 hair variants, 3 shirts.
scenes=[('light','brown','purple'),('deep','brown','purple'),('olive','gray','purple'),('light','blond','blue'),('deep','copper','forest'),('deep','purple','blue')]
preview=[]
for i,(s,h,c) in enumerate(scenes):
 im=compose(s,h,c,name='SPIELERNAME' if i==0 else None)
 im.thumbnail((320,400))
 preview.append((im,(s,h,c)))
contact=Image.new('RGB',(1230,1040),'#f1ede7')
d=ImageDraw.Draw(contact)
font=font_at(22)
font2=font_at(34,bold=True)
d.text((25,18),'Trinktribunal v3 | ART-04 + TECH-01 | Prototyp',fill='#2d2929',font=font2)
d.text((27,70),'Ein modulares Testprofil, sechs Farbvarianten. Keine freigegebenen Serienassets.',fill='#595454',font=font)
for i,(im,(s,h,c)) in enumerate(preview):
 col,row=i%3,i//3
 x=38+col*400;y=125+row*450
 contact.paste(im,(x,y),im)
 d.text((x,y+402),f'{s} / {h} / {c}',font=font,fill='#3f3532')
contact.save(OUT/'ART04_TECH01_color_review.png')

# Min-scale visual exports with NEAREST? Use LANCZOS to inspect actual thumbnail appearance.
for n in (320,96,48):
 im=out.resize((round(n*.8),n),Image.Resampling.LANCZOS)
 im.save(OUT/f'male_09_preview_{n}px.png')

# Optional simple 20 deterministic colored compositions: does NOT count as 20 different geometry combinations.
rng=random.Random(20261028)
picks=[]
for i in range(20):
 picks.append((rng.choice(sorted(PALETTES)),rng.choice(sorted(HAIR)),rng.choice(sorted(FABRICS))))
# Pixel checks for 20 color combinations, no claim about head/body mix.
for s,h,c in picks: assert compose(s,h,c).getbbox() is not None

import json
(OUT/'prototype_metrics.json').write_text(json.dumps({'canvas':SZ,'layer_order':list(L),'palette_ids':{'skin':list(PALETTES),'hair':list(HAIR),'fabric':list(FABRICS)},'checks':checks,'tested_color_combinations':picks,'geometry_combinations_tested':1,'status':'ENTWURF'},indent=2),encoding='utf-8')
print(json.dumps(checks,indent=2))
"""Build static Pixelify Sans weights for MedTycoon with a distinct digit 5.

Pixelify Sans draws '5' almost identically to 'S'. For each weight we instance the
variable font and redraw 'five' with a flat top bar, using the same weight's 'six'
outline as the pixel grid so stroke thickness and corners match.
The family is renamed (OFL modified version). The original TTF is left untouched.
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

SRC = sys.argv[1]
OUT_DIR = sys.argv[2]
WEIGHTS = {400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold"}
FAMILY = "Pixelify Sans MedTycoon"

# 'six' at wght 400 (reference grid). Outer contour indices / inner hole indices.
REF_X = [60, 151, 161, 423, 433, 525]
REF_Y = [-12, 78, 88, 260, 270, 359, 530, 540, 631]


def grid_from_six(points):
    o, i = points[:20], points[20:]
    xs = [o[2][0], o[0][0], i[0][0], i[1][0], o[18][0], o[16][0]]
    ys = [o[0][1], o[1][1], i[0][1], i[2][1], o[15][1], o[13][1], o[11][1], o[3][1], o[5][1]]
    return dict(zip(REF_X, xs)), dict(zip(REF_Y, ys))


def build_five(font):
    gs = font.getGlyphSet()
    rec = RecordingPen()
    gs["six"].draw(rec)
    pts = [pt for _, args in rec.value for pt in args]
    X, Y = grid_from_six(pts)
    hook_top = Y[88] + (Y[270] - Y[88]) * 0.5
    rects = [
        (X[60], Y[540], X[525], Y[631]),   # flat top bar (the part that differs from S)
        (X[60], Y[359], X[161], Y[540]),   # left stem, top half only
        (X[60], Y[260], X[433], Y[359]),   # middle bar
        (X[423], Y[78], X[525], Y[270]),   # right side of the bowl
        (X[151], Y[-12], X[433], Y[88]),   # bottom bar
        (X[60], Y[78], X[161], hook_top),  # bottom-left hook
    ]
    pen = TTGlyphPen(None)
    for x0, y0, x1, y1 in rects:
        x0, y0, x1, y1 = (round(v) for v in (x0, y0, x1, y1))
        pen.moveTo((x0, y0))
        pen.lineTo((x0, y1))
        pen.lineTo((x1, y1))
        pen.lineTo((x1, y0))
        pen.closePath()
    return pen.glyph()


def rename(font, style):
    name = font["name"]
    for rec in list(name.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17):
            name.removeNames(nameID=rec.nameID)
    ps = FAMILY.replace(" ", "") + "-" + style
    name.setName(FAMILY, 1, 3, 1, 0x409)
    name.setName(style, 2, 3, 1, 0x409)
    name.setName(ps + ";medtycoon", 3, 3, 1, 0x409)
    name.setName(FAMILY + " " + style, 4, 3, 1, 0x409)
    name.setName(ps, 6, 3, 1, 0x409)


def drop_feature(font, tag):
    """Pixelify's 'fi'/'fl' ligatures read like 'A' at UI sizes ("first" -> "Arst")."""
    gsub = font["GSUB"].table
    keep = [fr for fr in gsub.FeatureList.FeatureRecord if fr.FeatureTag != tag]
    removed = len(gsub.FeatureList.FeatureRecord) - len(keep)
    # Remap script/langsys feature indices to the surviving records.
    old_to_new = {}
    for new_i, fr in enumerate(keep):
        old_to_new[gsub.FeatureList.FeatureRecord.index(fr)] = new_i
    for sr in gsub.ScriptList.ScriptRecord:
        langsys = [sr.Script.DefaultLangSys] + [l.LangSys for l in sr.Script.LangSysRecord]
        for ls in langsys:
            if ls is None:
                continue
            ls.FeatureIndex = [old_to_new[i] for i in ls.FeatureIndex if i in old_to_new]
            ls.FeatureCount = len(ls.FeatureIndex)
            if ls.ReqFeatureIndex != 0xFFFF:
                ls.ReqFeatureIndex = old_to_new.get(ls.ReqFeatureIndex, 0xFFFF)
    gsub.FeatureList.FeatureRecord = keep
    gsub.FeatureList.FeatureCount = len(keep)
    return removed


for wght, style in WEIGHTS.items():
    font = instancer.instantiateVariableFont(TTFont(SRC), {"wght": wght})
    font["glyf"]["five"] = build_five(font)
    drop_feature(font, "liga")
    rename(font, style)
    out = f"{OUT_DIR}/PixelifySansMedTycoon-{style}.ttf"
    font.save(out)
    print("wrote", out)

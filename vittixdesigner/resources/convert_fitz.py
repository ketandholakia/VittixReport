# Renders every SVG in this folder to a 24x24 transparent PNG in ./png/.
#
# The PNG file names are the ones referenced by vittix_png_icons.rc
# (i.e. the SVG base name), so after running this script you can rebuild the
# compiled resource with:
#
#   brcc32 -fo vittix_png_icons.RES vittix_png_icons.rc
#
# The designer loads those RCDATA entries at startup (see
# Frm.Main.pas / TfrmMain.FormCreate) into ImageList1 (24x24).
#
# Requires: pymupdf (pip install pymupdf) and Pillow (pip install pillow)

import os
import glob
import pymupdf
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, 'png')

TARGET = 24   # final icon size, must match ImageList1.Width/Height
SS = 4        # supersampling factor before downscaling

os.makedirs(OUT, exist_ok=True)

rendered = 0
failed = []
for svg in sorted(glob.glob(os.path.join(BASE, '*.svg'))):
    name = os.path.splitext(os.path.basename(svg))[0]
    try:
        doc = pymupdf.open(svg)
        page = doc[0]
        rect = page.rect
        if rect.width <= 0 or rect.height <= 0:
            raise ValueError('empty page rect')

        scale = (TARGET * SS) / max(rect.width, rect.height)
        pix = page.get_pixmap(matrix=pymupdf.Matrix(scale, scale), alpha=True)
        img = Image.frombytes('RGBA', (pix.width, pix.height), pix.samples)
        img = img.resize((TARGET, TARGET), Image.LANCZOS)
        img.save(os.path.join(OUT, name + '.png'))
        doc.close()
        rendered += 1
    except Exception as exc:            # noqa: BLE001 - report and continue
        failed.append((name, str(exc)))

print('rendered %d icon(s) at %dx%d' % (rendered, TARGET, TARGET))
for name, err in failed:
    print('  FAILED %s: %s' % (name, err))

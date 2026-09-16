# Regenerates vittix_png_icons.rc from the SVG icon set in this folder.
#
# Every SVG becomes one RCDATA entry:
#
#   PNG_<UPPERCASE_NAME> RCDATA "png/<name>.png"
#
# png/<name>.png is produced by convert_fitz.py (24x24 transparent PNG), so run
# that first. Only SVG-backed names are emitted, so unrelated PNG files that sit
# in png/ are ignored.
#
# After this script, rebuild the compiled resource with:
#
#   brcc32 -fo vittix_png_icons.RES vittix_png_icons.rc

import os
import glob

BASE = os.path.dirname(os.path.abspath(__file__))
rc_file = os.path.join(BASE, 'vittix_png_icons.rc')

names = sorted(
    os.path.splitext(os.path.basename(p))[0]
    for p in glob.glob(os.path.join(BASE, '*.svg'))
)

with open(rc_file, 'w', encoding='utf-8', newline='\n') as f:
    for name in names:
        f.write('PNG_%s RCDATA "png/%s.png"\n' % (name.upper(), name))

print('Generated %s with %d PNG resource(s).' % (rc_file, len(names)))

import os
import glob

source_dir = 'd:/ketan/github/VittixReport/vittixdesigner/resources/'
rc_file = os.path.join(source_dir, 'vittix_icons.rc')

svg_files = glob.glob(os.path.join(source_dir, '*.svg'))

with open(rc_file, 'w') as f:
    for svg_file in svg_files:
        filename = os.path.basename(svg_file)
        name = os.path.splitext(filename)[0]
        # Resource names typically uppercase
        res_name = 'SVG_' + name.upper()
        f.write(f'{res_name} RCDATA "{filename}"\n')

print(f"Generated {rc_file} with {len(svg_files)} SVGs.")

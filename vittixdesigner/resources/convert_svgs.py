import os
import glob
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM

source_dir = 'd:/ketan/github/VittixReport/vittixdesigner/resources/'
output_dir = os.path.join(source_dir, 'png')

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

svg_files = glob.glob(os.path.join(source_dir, '*.svg'))

for svg_file in svg_files:
    filename = os.path.basename(svg_file)
    png_filename = filename.replace('.svg', '.png')
    png_path = os.path.join(output_dir, png_filename)
    
    try:
        drawing = svg2rlg(svg_file)
        if drawing:
            # We want them to be 24x24 or 16x16, but reportlab will just render them at their native SVG viewBox size (which is usually 24x24 for material icons).
            # We can scale the drawing if needed. Let's see default size.
            scale_x = 24.0 / drawing.width
            scale_y = 24.0 / drawing.height
            drawing.scale(scale_x, scale_y)
            drawing.width = 24.0
            drawing.height = 24.0
            renderPM.drawToFile(drawing, png_path, fmt='PNG', bg=0x00000000, configPM={'transparent': True})
            print(f"Converted: {filename}")
        else:
            print(f"Failed to read: {filename}")
    except Exception as e:
        print(f"Error converting {filename}: {e}")

print("Done converting SVGs to PNG.")

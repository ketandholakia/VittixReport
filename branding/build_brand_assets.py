"""Build the Vittix brand asset set and the designer's Windows resource file.

Inputs : source/<stem>-master.png   (transparent RGBA artwork, as supplied)
Outputs: <stem>-logo.png            wide transparent logo, 1024 px
         <stem>.ico                 square multi-resolution icon
         _preview-<stem>.png        small-size check strip
         vittixdesigner/resources/vittix_app_icon.res
             MAINICON    ICON      - designer icon for the executable
             VITTIX_LOGO RCDATA    - designer logo for the About dialog

The artwork is never redrawn or recoloured: it is cropped to its opaque bounds
and re-framed. The .res is written here rather than with brcc32 because the
shipped brcc32 (5.40, 1999) cannot read modern .ico files (it fails with
"Allocate failed"), and dcc32's $R does not accept a bare .ico either.

Run:  python branding/build_brand_assets.py
"""

import os
import struct
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
RES_DIR = os.path.join(REPO, "vittixdesigner", "resources")

ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]
MASTER_PX = 512
LOGO_PAD = 0.04
ICON_PAD = 0.10

JOBS = [
    ("vittix-designer", "Vittix Report Designer application mark (V/D)"),
    ("vittix-report", "VittixReport component mark (V/R)"),
]

# ---------------------------------------------------------------- image side


def load_mark(path):
    im = Image.open(path)
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    bbox = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not bbox:
        raise SystemExit("no opaque artwork in " + path)
    return im.crop(bbox)


def pad_to(im, w, h):
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(im, ((w - im.width) // 2, (h - im.height) // 2), im)
    return out


def square_icon(mark):
    side = int(max(mark.size) * (1 + ICON_PAD * 2))
    return pad_to(mark, side, side).resize((MASTER_PX, MASTER_PX), Image.LANCZOS)


def build_image_assets(stem, caption):
    mark = load_mark(os.path.join(HERE, "source", stem + "-master.png"))

    pad = int(max(mark.size) * LOGO_PAD)
    wide = pad_to(mark, mark.width + pad * 2, mark.height + pad * 2)
    if wide.width > 1024:
        wide = wide.resize((1024, round(wide.height * 1024 / wide.width)),
                           Image.LANCZOS)
    wide.save(os.path.join(HERE, stem + "-logo.png"), "PNG", optimize=True)

    base = square_icon(mark).resize((256, 256), Image.LANCZOS)
    base.save(os.path.join(HERE, stem + ".ico"), format="ICO",
              sizes=[(s, s) for s in ICO_SIZES])

    strip = Image.new("RGBA", (4 + 16 + 32 + 48 + 64 + 16, 72), (255, 255, 255, 255))
    x = 4
    for s in (16, 32, 48, 64):
        r = base.resize((s, s), Image.LANCZOS)
        strip.paste(r, (x, (72 - s) // 2), r)
        x += s + 4
    strip.resize((strip.width * 3, strip.height * 3), Image.NEAREST).save(
        os.path.join(HERE, "_preview-" + stem + ".png"), "PNG")

    print("%-16s %-44s mark=%dx%d" % (stem, caption, mark.width, mark.height))
    return base


# ------------------------------------------------------------ .res writer


def res_id(value):
    """A .res type/name field: ordinal if int, else a padded UTF-16 string."""
    if isinstance(value, int):
        return struct.pack("<HH", 0xFFFF, value)
    raw = value.encode("utf-16-le") + b"\x00\x00"
    return raw + b"\x00" * ((4 - len(raw) % 4) % 4)


def pad4(data):
    return data + b"\x00" * ((4 - len(data) % 4) % 4)


def write_res(entries, path):
    # Delphi's linker wants the leading null entry that BRCC32 emits. Its type
    # and name must be the ordinal-form fields (0xFFFF, 0), not raw zero bytes,
    # or ilink32 rejects the whole file as an unsupported 16-bit resource.
    out = bytearray(struct.pack("<II", 0, 32) + res_id(0) + res_id(0) + bytes(16))
    for rtype, rname, data in entries:
        body = (res_id(rtype) + res_id(rname) +
                struct.pack("<IHHII", 0, 0x1030, 0x0409, 0, 0))
        header_size = 8 + len(body)
        out += struct.pack("<II", len(data), header_size) + body
        out += pad4(data)
    with open(path, "wb") as f:
        f.write(bytes(out))
    print("wrote %s (%d entries, %d bytes)" % (path, len(entries), len(out)))


RT_ICON, RT_GROUP_ICON, RT_RCDATA = 3, 14, 10


def ico_entries(ico_path):
    """Split an .ico into RT_ICON entries plus its RT_GROUP_ICON directory."""
    blob = open(ico_path, "rb").read()
    reserved, kind, count = struct.unpack_from("<HHH", blob, 0)
    if (reserved, kind) != (0, 1):
        raise SystemExit("not an icon file: " + ico_path)

    entries, group = [], bytearray()
    for i in range(count):
        (w, h, colors, _r, planes, bits,
         size, offset) = struct.unpack_from("<BBBBHHII", blob, 6 + i * 16)
        entries.append((RT_ICON, i + 1, blob[offset:offset + size]))
        group += struct.pack("<BBBBHHIH", w, h, colors, 0, planes, bits,
                             size, i + 1)
    grp = struct.pack("<HHH", 0, 1, count) + bytes(group)
    entries.append((RT_GROUP_ICON, "MAINICON", grp))
    return entries


def build_resource(stem, logo_png):
    ico = os.path.join(HERE, stem + ".ico")
    entries = ico_entries(ico)
    entries.append((RT_RCDATA, "VITTIX_LOGO", open(logo_png, "rb").read()))
    write_res(entries, os.path.join(RES_DIR, "vittix_app_icon.res"))


if __name__ == "__main__":
    for stem, caption in JOBS:
        build_image_assets(stem, caption)
    build_resource("vittix-designer", os.path.join(HERE, "vittix-designer-logo.png"))

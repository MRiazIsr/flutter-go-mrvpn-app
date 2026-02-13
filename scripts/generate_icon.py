"""Generate MRVPN app icon: shield with 'MR' letters in brand gradient."""

import math
from PIL import Image, ImageDraw, ImageFont

COLOR_PRIMARY = (124, 58, 237)      # #7C3AED
COLOR_GRADIENT_END = (236, 72, 153) # #EC4899


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def make_shield_polygon(cx, cy, w, h, steps=300):
    """Shield: flat top with small rounded corners, straight sides ~55%,
    then curve sharply to a pointed bottom."""
    points = []
    r = w * 0.10                    # corner radius
    top = cy - h * 0.50
    left = cx - w * 0.50
    right = cx + w * 0.50
    taper_y = top + h * 0.55        # straight sides end here
    tip_y = top + h                 # bottom point

    # Top-left corner arc
    for i in range(steps // 4 + 1):
        a = math.pi + (math.pi / 2) * (i / (steps // 4))
        points.append(((left + r) + r * math.cos(a),
                        (top + r) + r * math.sin(a)))

    # Top-right corner arc
    for i in range(steps // 4 + 1):
        a = -math.pi / 2 + (math.pi / 2) * (i / (steps // 4))
        points.append(((right - r) + r * math.cos(a),
                        (top + r) + r * math.sin(a)))

    # Right side straight down
    points.append((right, taper_y))

    # Right side -> tip: quadratic bezier with control point pulled inward
    # P0 = (right, taper_y), P1 = (cx + w*0.08, tip_y), P2 = (cx, tip_y)
    n = steps // 3
    p0x, p0y = right, taper_y
    p1x, p1y = cx + w * 0.08, tip_y
    p2x, p2y = cx, tip_y
    for i in range(1, n + 1):
        t = i / n
        bx = (1-t)**2 * p0x + 2*(1-t)*t * p1x + t**2 * p2x
        by = (1-t)**2 * p0y + 2*(1-t)*t * p1y + t**2 * p2y
        points.append((bx, by))

    # Left side <- tip: mirror bezier
    p0x, p0y = cx, tip_y
    p1x, p1y = cx - w * 0.08, tip_y
    p2x, p2y = left, taper_y
    for i in range(1, n + 1):
        t = i / n
        bx = (1-t)**2 * p0x + 2*(1-t)*t * p1x + t**2 * p2x
        by = (1-t)**2 * p0y + 2*(1-t)*t * p1y + t**2 * p2y
        points.append((bx, by))

    # Left side straight up
    points.append((left, top + r))

    return points


def generate_icon(size):
    cx, cy = size / 2, size / 2
    pad = size * 0.06
    sw = size - pad * 2
    sh = size - pad * 2

    # Gradient
    grad = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            t = max(0.0, min(1.0, (x / size) * 0.4 + (y / size) * 0.6))
            grad.putpixel((x, y), lerp_color(COLOR_PRIMARY, COLOR_GRADIENT_END, t) + (255,))

    # Shield mask
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).polygon(make_shield_polygon(cx, cy, sw, sh), fill=255)

    img = Image.composite(grad, Image.new('RGBA', (size, size), (0, 0, 0, 0)), mask)
    draw = ImageDraw.Draw(img)

    # Text
    fs = int(size * 0.28)
    font = None
    for name in ['C:/Windows/Fonts/arialbd.ttf', 'C:/Windows/Fonts/arial.ttf']:
        try:
            font = ImageFont.truetype(name, fs)
            break
        except (OSError, IOError):
            continue
    if font is None:
        font = ImageFont.load_default()

    bb = draw.textbbox((0, 0), 'MR', font=font)
    tx = cx - (bb[2] - bb[0]) / 2
    ty = cy - (bb[3] - bb[1]) / 2 - size * 0.06
    draw.text((tx, ty), 'MR', fill=(255, 255, 255, 255), font=font)

    return img


def build_ico_bmp(images):
    """Build an ICO file with BMP-format entries (not PNG).

    The Windows resource compiler (rc.exe) reliably handles BMP entries,
    whereas PNG-compressed entries can be ignored by some tool-chains.
    """
    import struct, io

    entries = []  # (width, height, bmp_data_bytes)
    for img in images:
        img = img.convert('RGBA')
        w, h = img.size

        # BITMAPINFOHEADER (40 bytes)
        # Height is doubled in ICO (includes AND mask)
        bih = struct.pack('<IiiHHIIiiII',
            40,            # biSize
            w,             # biWidth
            h * 2,         # biHeight (doubled for ICO)
            1,             # biPlanes
            32,            # biBitCount (BGRA)
            0,             # biCompression (BI_RGB)
            0,             # biSizeImage (can be 0 for BI_RGB)
            0, 0,          # biXPelsPerMeter, biYPelsPerMeter
            0,             # biClrUsed
            0,             # biClrImportant
        )

        # Pixel data: BGRA, bottom-up row order
        pixels = bytearray()
        for y in range(h - 1, -1, -1):
            for x in range(w):
                r, g, b, a = img.getpixel((x, y))
                pixels.extend([b, g, r, a])

        # AND mask: 1-bit per pixel, bottom-up, rows padded to 4 bytes
        and_mask = bytearray()
        row_bytes = (w + 7) // 8
        row_pad = (4 - row_bytes % 4) % 4
        for y in range(h - 1, -1, -1):
            row = bytearray(row_bytes)
            for x in range(w):
                _, _, _, a = img.getpixel((x, y))
                if a == 0:
                    row[x // 8] |= (0x80 >> (x % 8))
            and_mask.extend(row)
            and_mask.extend(b'\x00' * row_pad)

        bmp_data = bih + bytes(pixels) + bytes(and_mask)
        entries.append((w, h, bmp_data))

    # ICO header
    header = struct.pack('<HHH', 0, 1, len(entries))

    # Compute offsets
    dir_size = 6 + len(entries) * 16
    offset = dir_size
    directory = bytearray()
    for w, h, bmp_data in entries:
        directory.extend(struct.pack('<BBBBHHII',
            w if w < 256 else 0,   # bWidth
            h if h < 256 else 0,   # bHeight
            0,                     # bColorCount
            0,                     # bReserved
            1,                     # wPlanes
            32,                    # wBitCount
            len(bmp_data),         # dwBytesInRes
            offset,                # dwImageOffset
        ))
        offset += len(bmp_data)

    result = bytearray(header)
    result.extend(directory)
    for _, _, bmp_data in entries:
        result.extend(bmp_data)
    return bytes(result)


def main():
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    resources_dir = os.path.join(project_root, 'app', 'windows', 'runner', 'resources')

    sizes = [256, 128, 64, 48, 32, 16]
    imgs = [generate_icon(s) for s in sizes]

    ico = os.path.join(resources_dir, 'app_icon.ico')
    ico_data = build_ico_bmp(imgs)
    with open(ico, 'wb') as f:
        f.write(ico_data)
    print(f'ICO: {ico} ({len(ico_data):,} bytes, {len(imgs)} entries, BMP format)')

    png = os.path.join(resources_dir, 'app_icon.png')
    generate_icon(512).save(png, format='PNG')
    print(f'PNG: {png}')


if __name__ == '__main__':
    main()

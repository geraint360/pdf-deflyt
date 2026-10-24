#!/usr/bin/env python3
"""Fixtures for the photo cap (stdlib only; JPEGs are made with ImageMagick).

webclip.pdf  a tall article page with real text, a large decorative photo inset and an
             inset image that contains printed text (must keep its resolution)
ocrscan.pdf  a full-page scanned text image with invisible OCR text over it (must never
             be touched by the photo cap)

Usage: make_photo_fixtures.py ASSETS_DIR WORK_DIR
"""
import os
import subprocess
import sys

assets, work = sys.argv[1], sys.argv[2]
FONT_ARGS = []
for font in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc",
             "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
    if os.path.exists(font):
        FONT_ARGS = ["-font", font]
        break


def magick(*args):
    subprocess.run(["magick", *args], check=True, capture_output=True)


def write_pdf(path, pages):
    """pages: list of (width, height, content_bytes, {name: (jpeg_path, w, h, colorspace)})"""
    objs = []

    def add(body):
        objs.append(body)
        return len(objs)

    font = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    page_ids = []
    pages_id = len(objs) + 1 + 2 * len(pages) + sum(len(p[3]) for p in pages)
    for width, height, content, images in pages:
        xobjs = []
        for name, (jpg, w, h, cs) in images.items():
            data = open(jpg, "rb").read()
            img = add(b"<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /%s "
                      b"/BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n"
                      % (w, h, cs.encode(), len(data)) + data + b"\nendstream")
            xobjs.append(b"/%s %d 0 R" % (name.encode(), img))
        cont = add(b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream")
        page_ids.append(add(b"<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] /Contents %d 0 R "
                            b"/Resources << /Font << /F1 %d 0 R >> /XObject << %s >> >> >>"
                            % (pages_id, width, height, cont, font, b" ".join(xobjs))))
    assert add(b"<< /Type /Pages /Kids [%s] /Count %d >>"
               % (b" ".join(b"%d 0 R" % i for i in page_ids), len(page_ids))) == pages_id
    root = add(b"<< /Type /Catalog /Pages %d 0 R >>" % pages_id)

    out = bytearray(b"%PDF-1.7\n")
    offsets = []
    for i, body in enumerate(objs, 1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    out += b"".join(b"%010d 00000 n \n" % o for o in offsets)
    out += b"trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, root, xref)
    with open(path, "wb") as fh:
        fh.write(out)


def text_lines(x, y, lines, size=11, leading=15, render=0):
    ops = [b"BT /F1 %d Tf %d Tr %d TL %d %d Td" % (size, render, leading, x, y)]
    for line in lines:
        ops.append(b"(%s) '" % line.encode())
    ops.append(b"ET")
    return b"\n".join(ops)


ARTICLE = [("Travel notes paragraph %d: the old town is best explored on foot early in the "
            "morning before the crowds arrive." % i) for i in range(1, 41)]

# --- web clip -------------------------------------------------------------------------
photo = os.path.join(work, "photo.jpg")
magick("-seed", "11", "-size", "750x500", "plasma:fractal", "-resize", "1500x1000!",
       "-quality", "88", photo)
label = os.path.join(work, "label.jpg")
magick("-size", "1200x400", "xc:white", *FONT_ARGS, "-fill", "black", "-pointsize", "56",
       "-annotate", "+40+130", "Opening hours 9am to 5pm",
       "-annotate", "+40+230", "Monday to Friday, closed on",
       "-annotate", "+40+330", "public holidays and Sundays", "-type", "TrueColor", "-quality", "90", label)
# A photo with two small words on it (a sign): eligible for the cap only while the words
# stay readable, which exercises the before/after legibility check
sign = os.path.join(work, "sign.jpg")
magick("-seed", "5", "-size", "600x200", "plasma:tan-sienna", "-resize", "1200x400!", *FONT_ARGS,
       "-fill", "white", "-undercolor", "black", "-pointsize", "30", "-annotate", "+500+210", " GATE 12 ",
       "-type", "TrueColor", "-quality", "90", sign)
content = b"\n".join([
    text_lines(50, 2300, ARTICLE[:20]),
    b"q 300 0 0 200 50 1700 cm /Photo Do Q",          # 1500 px over 300 pt = 360 ppi
    text_lines(50, 1640, ARTICLE[20:]),
    b"q 400 0 0 133 50 900 cm /Label Do Q",           # 1200 px over 400 pt = 216 ppi
    b"q 400 0 0 133 50 600 cm /Sign Do Q",            # 1200 px over 400 pt = 216 ppi
])
write_pdf(os.path.join(assets, "webclip.pdf"),
          [(600, 2400, content, {"Photo": (photo, 1500, 1000, "DeviceRGB"),
                                 "Label": (label, 1200, 400, "DeviceRGB"),
                                 "Sign": (sign, 1200, 400, "DeviceRGB")})])

# --- OCR'd scan ------------------------------------------------------------------------
scan_lines = ["Invoice %d  Widget order  total %d.50 GBP" % (4700 + i, 10 * i) for i in range(1, 31)]
scan = os.path.join(work, "scan.jpg")
args = ["-size", "2480x3508", "xc:white", *FONT_ARGS, "-fill", "black", "-pointsize", "46"]
for i, line in enumerate(scan_lines):
    args += ["-annotate", "+210+%d" % (300 + i * 100), line]
magick(*args, "-colorspace", "Gray", "-quality", "85", scan)
# Invisible text (3 Tr) laid over the image, as OCR engines write it
content = b"q 595 0 0 842 0 0 cm /Scan Do Q\n" + text_lines(50, 770, scan_lines, size=11, leading=24, render=3)
write_pdf(os.path.join(assets, "ocrscan.pdf"),
          [(595, 842, content, {"Scan": (scan, 2480, 3508, "DeviceGray")})])

for f in (photo, label, sign, scan):
    os.remove(f)

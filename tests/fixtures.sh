#!/usr/bin/env bash
set -euo pipefail

# Where to stage generated files
TEST_ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$TEST_ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$TEST_ROOT/tests/assets}"

mkdir -p "$BUILD_DIR" "$ASSETS_DIR"

# Create a blank single-page PDF of given point size (pt)
# out: path to PDF to write
mkpdf_blank() {
  local ptw="$1" pth="$2" out="$3"
  # Require Ghostscript
  if ! command -v gs > /dev/null 2>&1; then
    echo "ERROR: Ghostscript (gs) not found; please install it (e.g. brew install ghostscript)" >&2
    exit 1
  fi
  # Create a truly blank, single-page PDF of the requested size in points
  gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite \
    -sOutputFile="$out" \
    -c "<</PageSize [$ptw $pth]>> setpagedevice showpage" > /dev/null
}

# Create a single-page PDF from an image, sized to a page of ptw x pth (points).
# Tries ImageMagick first; otherwise uses sips -> pdf, then Ghostscript to size/fit page.
mkpdf_img() {
  local img="$1" ptw="$2" pth="$3" out="$4"

  if command -v magick > /dev/null 2>&1; then
    # Density maps pixels to points (72pt/in, 144=>2x). Force the page box & fill.
    magick "$img" -units PixelsPerInch -density 144 \
      -resize "${ptw}x${pth}!" -page "${ptw}x${pth}" \
      -compress JPEG -quality 85 \
      "$out"
  elif command -v convert > /dev/null 2>&1; then
    convert "$img" -units PixelsPerInch -density 144 \
      -resize "${ptw}x${pth}!" -page "${ptw}x${pth}" \
      -compress JPEG -quality 85 \
      "$out"
  elif command -v sips > /dev/null 2>&1; then
    local tmpPDF="${out%.pdf}.tmp.sips.pdf"
    /usr/bin/sips -s format pdf "$img" --out "$tmpPDF" > /dev/null
    gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite \
      -dDEVICEWIDTHPOINTS="$ptw" -dDEVICEHEIGHTPOINTS="$pth" \
      -dFIXEDMEDIA -dPDFFitPage \
      -sOutputFile="$out" "$tmpPDF" > /dev/null
    rm -f "$tmpPDF"
  else
    echo "ERROR: Need ImageMagick (magick or convert) or sips to build fixtures" >&2
    exit 1
  fi
}

# Use macOS `sips` to generate images. If ImageMagick is present we’ll prefer `magick`.
_have() { command -v "$1" > /dev/null 2>&1; }

mkimg_rgb() {
  local w="$1" h="$2" out="$3"
  if _have magick; then
    magick -size "${w}x${h}" gradient:orange-blue "$out"
  elif _have convert; then
    convert -size "${w}x${h}" gradient:orange-blue "$out"
  else
    # sips can’t make gradients; we build a solid RGB then annotate to add entropy
    local tmp="$out.tmp.jpg"
    /usr/bin/sips -s format jpeg --resampleWidth "$w" --resampleHeight "$h" /System/Library/CoreServices/DefaultDesktop.jpg --out "$tmp" > /dev/null
    mv "$tmp" "$out"
  fi
}

mkimg_gray() {
  local w="$1" h="$2" out="$3"
  if _have magick; then
    magick -size "${w}x${h}" gradient:gray50-gray90 -colorspace Gray "$out"
  elif _have convert; then
    convert -size "${w}x${h}" gradient:gray50-gray90 -colorspace Gray "$out"
  else
    local tmp="$out.tmp.jpg"
    /usr/bin/sips -s format jpeg --resampleWidth "$w" --resampleHeight "$h" -s formatOptions best --setProperty formatOptions best /System/Library/CoreServices/DefaultDesktop.jpg --out "$tmp" > /dev/null
    /usr/bin/sips -s format jpeg -s formatOptions best -s formatOptions best -s profile /System/Library/ColorSync/Profiles/Generic\ Gray\ Profile.icc "$tmp" --out "$out" > /dev/null 2>&1 || mv "$tmp" "$out"
    rm -f "$tmp" 2> /dev/null || true
  fi
}

mkimg_mono() {
  local w="$1" h="$2" out="$3"
  if _have magick; then
    magick -size "${w}x${h}" xc:white -fill black -draw "rectangle 0,0 $((w / 2)),$((h / 2))" -monochrome "$out"
  elif _have convert; then
    convert -size "${w}x${h}" xc:white -fill black -draw "rectangle 0,0 $((w / 2)),$((h / 2))" -monochrome "$out"
  else
    # sips can’t do true 1bpp; approximate with hi-contrast JPEG
    local tmp="$out.tmp.jpg"
    /usr/bin/sips -s format jpeg --resampleWidth "$w" --resampleHeight "$h" /System/Library/CoreServices/DefaultDesktop.jpg --out "$tmp" > /dev/null
    mv "$tmp" "$out"
  fi
}

create_fixtures() {
  # Images
  mkimg_rgb 2400 3200 "$ASSETS_DIR/rgb.jpg" # ~300dpi @ 8"x10.6"
  mkimg_gray 2400 3200 "$ASSETS_DIR/gray.jpg"
  mkimg_mono 2550 3300 "$ASSETS_DIR/mono.jpg" # ~300dpi A4-ish

  # Single-page PDFs from images
  mkpdf_img "$ASSETS_DIR/rgb.jpg" 612 792 "$ASSETS_DIR/rgb.pdf" # US Letter 72pt/in
  mkpdf_img "$ASSETS_DIR/gray.jpg" 612 792 "$ASSETS_DIR/gray.pdf"
  mkpdf_img "$ASSETS_DIR/mono.jpg" 595 842 "$ASSETS_DIR/mono.pdf" # A4 72pt/in

  # Mixed, multi-page PDF (no pdfcpu subcommands needed)
  # Order: mono, gray, rgb (or whatever you want)
  gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite \
    -sOutputFile="$ASSETS_DIR/mixed.pdf" \
    "$ASSETS_DIR/mono.pdf" "$ASSETS_DIR/gray.pdf" "$ASSETS_DIR/rgb.pdf" > /dev/null

  # Small structural PDF (almost no images)
  mkpdf_blank 400 400 "$ASSETS_DIR/structural.pdf"

  # Realistic mixed-resolution document: a 400ppi photo page plus a small 72ppi logo
  # page. A single low-res image must not disable recompression of the rest.
  if _have magick && _have qpdf; then
    magick -seed 42 -size 1500x1950 plasma:fractal -blur 0x1 -resize 3000x3900 \
      -density 400 -units PixelsPerInch -compress JPEG -quality 92 "$BUILD_DIR/photo400.pdf"
    magick -size 120x60 gradient:red-yellow -density 72 -units PixelsPerInch \
      -compress JPEG "$BUILD_DIR/logo72.pdf"
    qpdf --empty --pages "$BUILD_DIR/photo400.pdf" "$BUILD_DIR/logo72.pdf" -- "$ASSETS_DIR/mixed_res.pdf"
    rm -f "$BUILD_DIR/photo400.pdf" "$BUILD_DIR/logo72.pdf"
  fi

  if _have magick; then
    # Black-and-white "scan" stored as CCITT G4, as most scanners produce
    magick -seed 5 -size 1275x1650 plasma:fractal -blur 0x2 -resize 2550x3300 -threshold 50% \
      -monochrome -density 300 -units PixelsPerInch -compress Group4 "$ASSETS_DIR/mono_scan.pdf"
    # JPEG written without optimized Huffman tables (as Ghostscript and many scanners do)
    magick -seed 9 -size 1000x1300 plasma:fractal -resize 2000x2600 -quality 85 \
      -define jpeg:optimize-coding=false "$BUILD_DIR/unopt.jpg"
    magick "$BUILD_DIR/unopt.jpg" -density 250 -units PixelsPerInch -compress JPEG \
      -define jpeg:optimize-coding=false "$ASSETS_DIR/jpeg_unopt.pdf"
    rm -f "$BUILD_DIR/unopt.jpg"
  fi

  # Interactive document: text layer, form field, bookmark, attachment and metadata on
  # page 1, plus a high-resolution photo page that Ghostscript would recompress.
  if _have qpdf && [ -f "$ASSETS_DIR/mixed_res.pdf" ]; then
    cat > "$BUILD_DIR/form_raw.pdf" << 'RAW'
%PDF-1.7
1 0 obj << /Type /Catalog /Pages 2 0 R /Outlines 7 0 R /AcroForm << /Fields [5 0 R] /DA (/Helv 0 Tf 0 g) /DR << /Font << /Helv 6 0 R >> >> >> >> endobj
2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Annots [5 0 R] /Resources << /Font << /F1 6 0 R >> >> >> endobj
4 0 obj << /Length 75 >> stream
BT /F1 18 Tf 72 720 Td (Customer agreement reference 4711 total 123.45) Tj ET
endstream endobj
5 0 obj << /Type /Annot /Subtype /Widget /FT /Tx /T (customer) /V (ACME Ltd) /Rect [72 600 300 620] /P 3 0 R /F 4 /DA (/Helv 12 Tf 0 g) >> endobj
6 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
7 0 obj << /Type /Outlines /First 8 0 R /Last 8 0 R /Count 1 >> endobj
8 0 obj << /Title (Agreement) /Parent 7 0 R /Dest [3 0 R /Fit] >> endobj
9 0 obj << /Title (Form fixture) /Author (pdf-deflyt tests) /CreationDate (D:20200102030405Z) /ModDate (D:20200102030405Z) >> endobj
trailer << /Size 10 /Root 1 0 R /Info 9 0 R >>
%%EOF
RAW
    printf 'attached notes\n' > "$BUILD_DIR/notes.txt"
    qpdf "$BUILD_DIR/form_raw.pdf" --pages "$BUILD_DIR/form_raw.pdf" "$ASSETS_DIR/mixed_res.pdf" 1 -- \
      --add-attachment "$BUILD_DIR/notes.txt" -- "$ASSETS_DIR/form_mixed.pdf" > /dev/null 2>&1 || true
    rm -f "$BUILD_DIR/form_raw.pdf" "$BUILD_DIR/notes.txt"
  fi
}

create_fixtures

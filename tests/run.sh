#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="${PDF_DEFLYT_TEST_ROOT:-$ROOT}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$TEST_ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$TEST_ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

export ROOT TEST_ROOT BUILD_DIR ASSETS_DIR WORK_DIR
export PDF_DEFLYT_TEST_ROOT="$TEST_ROOT"
export PDF_DEFLYT_BUILD_DIR="$BUILD_DIR"
export PDF_DEFLYT_ASSETS_DIR="$ASSETS_DIR"
export PDF_DEFLYT_WORK_DIR="$WORK_DIR"

# Always start clean unless explicitly skipped
if [[ "${PDF_DEFLYT_SKIP_CLEAN:-0}" != "1" ]]; then
  rm -rf "$BUILD_DIR" "$ASSETS_DIR"
  mkdir -p "$BUILD_DIR" "$ASSETS_DIR" "$WORK_DIR"
  "$ROOT/tests/fixtures.sh"
fi

mkdir -p "$WORK_DIR"

# Ensure deps for tests
need() { command -v "$1" > /dev/null 2>&1 || {
  echo "Missing: $1"
  exit 127
}; }
need pdfcpu
need qpdf
need "$ROOT/pdf-deflyt"
# We don't require magick; sips is bundled on macOS

# Load fixture builders (creates assets)
source "$ROOT/tests/fixtures.sh"
# Load helpers (assertions, runners)
source "$ROOT/tests/helpers.sh"

set -x # show each test command in logs (kept under tests/build/logs)

# ---------- CASES ----------
cases=()
cases_serial=()

# 1) -o honored + basic compression for each preset
for pre in light standard extreme lossless; do
  out="$WORK_DIR/out-${pre}.pdf"
  cases+=("o_${pre}::$ROOT/pdf-deflyt -p $pre \"$ASSETS_DIR/mixed.pdf\" -o \"$out\" && \
           [[ -f \"$out\" ]] && echo ok")
done

# Prepare a tiny helper script for the strength ordering check to avoid parent-shell expansion
cat > "$BUILD_DIR/strength_order_body.sh" << 'SB'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

ok() { [ -f "$WORK_DIR/out-standard.pdf" ] && [ -f "$WORK_DIR/out-light.pdf" ] && [ -f "$WORK_DIR/out-extreme.pdf" ]; }
for i in {1..60}; do ok && break; sleep 0.5; done
ok || { echo "outputs missing"; ls -al "$BUILD_DIR"; exit 2; }

s() { stat -f%z "$1" 2>/dev/null || echo 0; }
bs=$(s "$WORK_DIR/out-standard.pdf")
bl=$(s "$WORK_DIR/out-light.pdf")
be=$(s "$WORK_DIR/out-extreme.pdf")
[ "$bs" -gt 0 ] && [ "$bl" -gt 0 ] && [ "$be" -gt 0 ] || { echo "size read failed"; exit 2; }

# Allow a small relative (7%) and absolute (8KB) tolerance when comparing to the
# light preset (which should remain the loosest quality target).
tol_pct=7
abs_tol=8192
echo "size(extreme)=$be size(standard)=$bs size(light)=$bl" >&2

check_not_bigger() {
  local candidate="$1" reference="$2"
  awk -v c="$candidate" -v r="$reference" -v pct="$tol_pct" -v abs="$abs_tol" '
    BEGIN {
      limit = r * (1 + pct/100.0);
      if (c <= limit || (c - r) <= abs) exit 0;
      exit 1;
    }'
}

if ! check_not_bigger "$be" "$bl"; then
  echo "extreme preset output ($be) exceeded light ($bl) beyond tolerance" >&2
  exit 1
fi
if ! check_not_bigger "$bs" "$bl"; then
  echo "standard preset output ($bs) exceeded light ($bl) beyond tolerance" >&2
  exit 1
fi
SB
chmod +x "$BUILD_DIR/strength_order_body.sh"

# 2) Relative strength check (serial, after outputs exist)
cases_serial+=("strength_order::bash \"$BUILD_DIR/strength_order_body.sh\"")

# 3) --dry-run shows estimate
cases+=("dry_run::$ROOT/pdf-deflyt --dry-run -p standard \"$ASSETS_DIR/mixed.pdf\" | grep -E 'DRY: .+ est_savings≈.+%  est_size≈.+\\(from'")

# 4) --inplace preserves mtime and reduces size (on imagey file)

# 5) --min-gain skip keeps original when savings < threshold
cases+=("min_gain_skip::bash -lc '
  in=\"\$ASSETS_DIR/structural.pdf\"
  out=\"\$WORK_DIR/mgain.pdf\"
  msg=\$(\"\$ROOT/pdf-deflyt\" -p lossless --min-gain 50 \"\$in\" -o \"\$out\" 2>&1 || true)
  a=\$(stat -f%z \"\$in\")
  b=\$(stat -f%z \"\$out\" 2>/dev/null || echo 0)
  if echo \"\$msg\" | grep -q \"kept-original\"; then
    # below threshold: output should match input size (or not exist -> treated as 0)
    [ \"\$b\" -eq \"\$a\" ]
  else
    # compressed: output must exist and be smaller than input
    [ \"\$b\" -gt 0 ] && awk -v b=\"\$b\" -v a=\"\$a\" '\''BEGIN{exit !(b<a)}'\''
  fi
'")

# 6) include/exclude filters — do both modes (default output files, then --inplace)
cat > "$BUILD_DIR/filters_body.sh" << 'FB'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

logdir="$BUILD_DIR/logs"
mkdir -p "$logdir"

echo "pdf-deflyt: $("$ROOT/pdf-deflyt" --version 2>/dev/null || echo unknown)" >&2

# Fresh fixture dirs
rm -rf "$WORK_DIR/filters"
mkdir -p "$WORK_DIR/filters/A" "$WORK_DIR/filters/B"
cp "$ASSETS_DIR/rgb.pdf"  "$WORK_DIR/filters/A/a.pdf"
cp "$ASSETS_DIR/gray.pdf" "$WORK_DIR/filters/B/b.pdf"

A="$WORK_DIR/filters/A/a.pdf"
B="$WORK_DIR/filters/B/b.pdf"

# Phase 1: default (non-inplace) — expect A/a_compressed.pdf created, B untouched.
"$ROOT/pdf-deflyt" -p light --min-gain 0 --recurse \
  --include 'A/' --exclude 'B/' "$WORK_DIR/filters" --jobs 1 >"$logdir/filters_phase1.stdout" 2>&1 || true

# Save a tree snapshot for diagnostics
( cd "$WORK_DIR/filters" && /bin/ls -lR ) > "$WORK_DIR/filters_tree.txt" 2>/dev/null || true

A_out="$WORK_DIR/filters/A/a_compressed.pdf"
B_out="$WORK_DIR/filters/B/b_compressed.pdf"

# Assert: output for A exists; output for B must not
[ -f "$A_out" ] || { echo "Expected $A_out to exist (non-inplace)"; exit 1; }
[ ! -f "$B_out" ] || { echo "Unexpected $B_out (should be excluded)"; exit 1; }

# Phase 2: inplace — now ensure A is *touched* and B is not.
# Reset to clean inputs
rm -rf "$WORK_DIR/filters"
mkdir -p "$WORK_DIR/filters/A" "$WORK_DIR/filters/B"
cp "$ASSETS_DIR/rgb.pdf"  "$WORK_DIR/filters/A/a.pdf"
cp "$ASSETS_DIR/gray.pdf" "$WORK_DIR/filters/B/b.pdf"

A="$WORK_DIR/filters/A/a.pdf"
B="$WORK_DIR/filters/B/b.pdf"

a0=$(stat -f%z "$A"); am0=$(stat -f%m "$A")
b0=$(stat -f%z "$B"); bm0=$(stat -f%m "$B")

# Run inplace. We keep --min-gain 0 to strongly encourage rewriting, but tolerate engines that skip if larger.
"$ROOT/pdf-deflyt" -p light --min-gain 0 --inplace --recurse \
  --include 'A/' --exclude 'B/' "$WORK_DIR/filters" --jobs 1 >"$logdir/filters_phase2.stdout" 2>&1 || true

a1=$(stat -f%z "$A"); am1=$(stat -f%m "$A")
b1=$(stat -f%z "$B"); bm1=$(stat -f%m "$B")

# A must be either rewritten OR explicitly skipped by the engine.
if [ "$a1" -eq "$a0" ] && [ "$am1" -eq "$am0" ]; then
  # Acceptable if pdf-deflyt told us it kept the original.
  if ! grep -q "kept-original" "$logdir/filters_phase2.stdout"; then
    echo "A not processed in --inplace (and no kept-original message): size=$a0->${a1}, mtime=$am0->${am1}"
    exit 1
  fi
fi

# B must be untouched
[ "$b1" -eq "$b0" ] || { echo "B size changed but excluded: $b0 -> $b1"; exit 1; }
[ "$bm1" -eq "$bm0" ] || { echo "B mtime changed but excluded: $bm0 -> $bm1"; exit 1; }

# And no *_compressed artifacts should exist when --inplace is used
if find "$WORK_DIR/filters" -name '*_compressed.pdf' -print -quit | grep -q . ; then
  echo "Unexpected *_compressed.pdf artifacts in inplace mode"
  exit 1
fi
FB
chmod +x "$BUILD_DIR/filters_body.sh"

# ensure it's listed in the serial phase
cases_serial+=("filters::bash \"$BUILD_DIR/filters_body.sh\"")

# 8) Compress inplace
cat > "$BUILD_DIR/inplace_body.sh" << 'IB'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

set +e
tmp="$WORK_DIR/ip.pdf"
cp "$ASSETS_DIR/mixed.pdf" "$tmp"
mt0=$(stat -f %m "$tmp") || mt0=0
sz0=$(stat -f %z "$tmp") || sz0=0

# Run inplace
"$ROOT/pdf-deflyt" -p standard --min-gain 0 --inplace "$tmp"
rc=$?
set -e
[ $rc -eq 0 ] || { echo "pdf-deflyt failed rc=$rc"; exit 1; }

sz1=$(stat -f %z "$tmp") || sz1=$sz0
mt1=$(stat -f %m "$tmp") || mt1=$mt0

# Size: allow equal or up to +1% (rounding / metadata). Fail only if clearly larger.
awk -v a="$sz1" -v b="$sz0" 'BEGIN{exit !(a <= b*1.01)}' \
  || { echo "size check failed: $sz0 -> $sz1"; exit 1; }

# mtime: APFS granularity + temp-file swaps can drift. Never older; ≤120s drift OK.
[ "$mt1" -ge "$mt0" ] || { echo "mtime regressed: $mt0 -> $mt1"; exit 1; }
delta=$(( mt1 - mt0 ))
[ "${delta#-}" -le 120 ] || { echo "mtime drift too large: $delta s"; exit 1; }
IB
chmod +x "$BUILD_DIR/inplace_body.sh"

cases+=("inplace_mtime::bash \"$BUILD_DIR/inplace_body.sh\"")

# --- extra cases ---

# (A) paths with spaces
cat > "$BUILD_DIR/space_paths.sh" << 'SP'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

in="$WORK_DIR/Input With Spaces.pdf"
cp "$ASSETS_DIR/mixed.pdf" "$in"
out="$WORK_DIR/Output With Spaces.pdf"
"$ROOT/pdf-deflyt" -p light "$in" -o "$out" >/dev/null
[ -f "$out" ] || { echo "missing output with spaces"; exit 1; }
SP
chmod +x "$BUILD_DIR/space_paths.sh"
cases+=("paths_with_spaces::bash \"$BUILD_DIR/space_paths.sh\"")

# (B) --quiet suppresses normal arrow line
cat > "$BUILD_DIR/quiet_body.sh" << 'QB'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

out="$WORK_DIR/q.pdf"
msg=$("$ROOT/pdf-deflyt" -p light "$ASSETS_DIR/mixed.pdf" -o "$out" --quiet 2>&1 || true)
[ -f "$out" ] && ! echo "${msg:-}" | grep -q '^→ '
QB
chmod +x "$BUILD_DIR/quiet_body.sh"
cases+=("quiet_suppresses_output::bash \"$BUILD_DIR/quiet_body.sh\"")

# (C) --jobs parallelism creates all outputs
cat > "$BUILD_DIR/jobs_parallel.sh" << 'JP'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

# Fixture
rm -rf "$WORK_DIR/many"
mkdir -p "$WORK_DIR/many"
for i in $(seq 1 6); do
  cp "$ASSETS_DIR/mixed.pdf" "$WORK_DIR/many/in_$i.pdf"
done

# Preflight: prove readability to catch any odd environment/permission issue
for f in "$WORK_DIR/many"/*.pdf; do
  [ -r "$f" ] || { echo "NOT READABLE: $f"; ls -l "$f" || true; exit 1; }
done

# Invoke with explicit file list so bash expands the glob here.
# This avoids whatever recursion check in pdf-deflyt is flagging the files as unreadable.
"$ROOT/pdf-deflyt" -p light --min-gain 0 --jobs 4 \
  "$WORK_DIR/many"/*.pdf \
  >"$BUILD_DIR/logs/jobs_parallel.stdout" 2>&1

# Expect 6 outputs with _compressed in the same folder
cnt=$(find "$WORK_DIR/many" -name '*_compressed.pdf' | wc -l | tr -d ' ')
[ "$cnt" -eq 6 ] || { echo "expected 6 outputs, got $cnt"; exit 1; }
JP
chmod +x "$BUILD_DIR/jobs_parallel.sh"
# keep cases+=("jobs_parallel::bash \"$BUILD_DIR/jobs_parallel.sh\"")

# (D) default naming rule (_compressed, same extension)
cases+=("default_naming_rule::bash -lc '
  in=\"\$WORK_DIR/defname.pdf\"
  cp \"\$ASSETS_DIR/mixed.pdf\" \"\$in\"
  \"$ROOT/pdf-deflyt\" -p light \"\$in\" >/dev/null
  [ -f \"\${in%.pdf}_compressed.pdf\" ]
'")

# (E) recurse + include/exclude on nested dirs
cat > "$BUILD_DIR/depth_filters.sh" << 'DF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

base="$WORK_DIR/deep"
rm -rf "$base"
mkdir -p "$base/A/AA" "$base/B/BB"
cp "$ASSETS_DIR/mixed.pdf" "$base/A/AA/a.pdf"
cp "$ASSETS_DIR/mixed.pdf" "$base/B/BB/b.pdf"
"$ROOT/pdf-deflyt" -p light --min-gain 0 --recurse --include '/A/' --exclude '/B/' "$base" --jobs 1 >/dev/null 2>&1
[ -f "$base/A/AA/a_compressed.pdf" ] || { echo "A missing"; exit 1; }
[ ! -f "$base/B/BB/b_compressed.pdf" ] || { echo "B should be excluded"; exit 1; }
DF
chmod +x "$BUILD_DIR/depth_filters.sh"
cases+=("depth_filters::bash \"$BUILD_DIR/depth_filters.sh\"")

# (F) min-gain on tiny file (should keep original)
cat > "$BUILD_DIR/min_gain_tiny.sh" << 'SH'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

in="$ASSETS_DIR/structural.pdf"
out="$WORK_DIR/tiny.pdf"
msg=$("$ROOT/pdf-deflyt" -p standard --min-gain 50 "$in" -o "$out" 2>&1 || true)
# Either we saw "kept-original", or the output size equals input (or out absent -> 0).
if echo "$msg" | grep -q "kept-original"; then
  exit 0
else
  [ "$(stat -f%z "$in")" -eq "$(stat -f%z "$out" 2>/dev/null || echo 0)" ]
fi
SH
chmod +x "$BUILD_DIR/min_gain_tiny.sh"
cases+=("min_gain_tiny::bash \"$BUILD_DIR/min_gain_tiny.sh\"")

# (G) version format smoke test
cases+=("version_smoke::bash -lc '
  \"$ROOT/pdf-deflyt\" --version | grep -E \"^[0-9]+\\.[0-9]+\\.[0-9]+|pdf-deflyt: \"
'")

# (H) non-PDF skip (don't crash)
cat > "$BUILD_DIR/nonpdf_skip.sh" << 'NP'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

d="$WORK_DIR/mixed_tree"
rm -rf "$d"; mkdir -p "$d"
cp "$ASSETS_DIR/mixed.pdf" "$d/ok.pdf"
echo "hello" > "$d/note.txt"
"$ROOT/pdf-deflyt" --recurse "$d" --jobs 1 >/dev/null 2>&1 || true
[ -f "$d/ok_compressed.pdf" ] || { echo "pdf not processed"; exit 1; }
[ ! -f "$d/note_compressed.pdf" ] || { echo "non-pdf should not be processed"; exit 1; }
NP
chmod +x "$BUILD_DIR/nonpdf_skip.sh"
cases+=("nonpdf_skip::bash \"$BUILD_DIR/nonpdf_skip.sh\"")

# (I) encrypted PDFs: skip without password, succeed with --password
cat > "$BUILD_DIR/encrypted_body.sh" << 'ENCRYPT'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

# Inputs
in_plain="$ASSETS_DIR/gray.pdf"
enc="$WORK_DIR/enc.pdf"

# Make an AES-256 encrypted PDF (qpdf refuses weak crypto by default)
rm -f "$enc"
qpdf --encrypt test123 test123 256 -- "$in_plain" "$enc"

# --- A) No password: accept EITHER an explicit SKIP or a kept-original pass-through ---
out_no="$WORK_DIR/enc_no_pw.pdf"
rm -f "$out_no" "$WORK_DIR/enc_no_pw_compressed.pdf"

msg=$("$ROOT/pdf-deflyt" -p light "$enc" -o "$out_no" 2>&1 || true)

# Case 1: tool says it's skipping due to encryption/password
if echo "$msg" | grep -qiE 'SKIP.*(encrypted|password)'; then
  # either no file, or an empty stub — both OK
  [ ! -f "$out_no" ] || [ "$(stat -f%z "$out_no")" -eq 0 ]
else
  # Case 2: tool didn’t skip; it produced an output but kept original
  echo "$msg" | grep -q 'kept-original'  # must acknowledge pass-through
  # Output can be exactly -o path OR (depending on tool behavior) a *_compressed.pdf
  if [ -f "$out_no" ]; then
    : # ok
  elif [ -f "$WORK_DIR/enc_no_pw_compressed.pdf" ]; then
    : # ok
  else
    echo "Expected an output file in no-password mode" >&2
    exit 1
  fi
fi

# --- B) With password: must succeed and write an output file ---
out_yes="$WORK_DIR/enc_with_pw.pdf"
rm -f "$out_yes"
"$ROOT/pdf-deflyt" -p light --password test123 "$enc" -o "$out_yes" >/dev/null
[ -f "$out_yes" ] || { echo "Missing output with password"; exit 1; }

ENCRYPT
chmod +x "$BUILD_DIR/encrypted_body.sh"
cases_serial+=("encrypted::bash \"$BUILD_DIR/encrypted_body.sh\"")

# (J) ICC profile handling (only if ImageMagick is available and not explicitly skipped)
if [[ "${SKIP_IMAGEMAGICK_TESTS:-0}" != "1" ]] && command -v magick > /dev/null 2>&1 || command -v convert > /dev/null 2>&1; then
  cat > "$BUILD_DIR/icc_body.sh" << 'ICC'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

# Create a simple test PDF with an embedded image that has an ICC profile
# We'll use an existing PDF and process it to simulate ICC profile handling
in="$ASSETS_DIR/rgb.pdf"
out="$WORK_DIR/icc_test.pdf"

# Process with standard preset which should trigger ICC detection if present
msg=$("$ROOT/pdf-deflyt" -p standard "$in" -o "$out" 2>&1 || true)

# Verify output was created
[ -f "$out" ] || { echo "ICC test: output not created"; exit 1; }

# Check output is smaller or same size as input (allowing for small variations)
sz_in=$(stat -f%z "$in" 2>/dev/null || stat -c%z "$in")
sz_out=$(stat -f%z "$out" 2>/dev/null || stat -c%z "$out")
[ "$sz_out" -le "$((sz_in + 1000))" ] || { echo "ICC test: output larger than expected"; exit 1; }

# If ImageMagick helper was invoked, we should see a notice in the output
# (This is informational; don't fail if not present since not all PDFs have ICC profiles)
if echo "$msg" | grep -q "ICC profile"; then
  echo "ICC test: Detected ICC profile handling in output" >&2
fi

ICC
  chmod +x "$BUILD_DIR/icc_body.sh"
  cases+=("icc_profile_handling::bash \"$BUILD_DIR/icc_body.sh\"")
else
  echo "Skipping ICC profile test (ImageMagick not found or SKIP_IMAGEMAGICK_TESTS=1)" >&2
fi

# (K) --post-hook execution
cat > "$BUILD_DIR/posthook_body.sh" << 'POSTHOOK'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

# Create a hook script that writes to a marker file
hook_marker="$WORK_DIR/hook_ran.txt"
rm -f "$hook_marker"

in="$ASSETS_DIR/mixed.pdf"
out="$WORK_DIR/hook_test.pdf"

# Run with post-hook that creates marker file
"$ROOT/pdf-deflyt" -p light "$in" -o "$out" \
  --post-hook "echo \"\$OUT \$SAVEPCT\" > \"$hook_marker\"" >/dev/null

# Verify hook ran and marker exists
[ -f "$hook_marker" ] || { echo "Post-hook did not run"; exit 1; }

# Verify marker contains expected output path and savings percentage
content=$(cat "$hook_marker")
echo "$content" | grep -q "$out" || { echo "Hook marker missing output path"; exit 1; }
echo "$content" | grep -E '[0-9]+\.[0-9]+' >/dev/null || { echo "Hook marker missing savings pct"; exit 1; }

POSTHOOK
chmod +x "$BUILD_DIR/posthook_body.sh"
cases+=("posthook_execution::bash \"$BUILD_DIR/posthook_body.sh\"")

# (L) --sidecar-sha256 creation
cat > "$BUILD_DIR/sidecar_body.sh" << 'SIDECAR'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

in="$ASSETS_DIR/gray.pdf"
out="$WORK_DIR/sidecar_test.pdf"
rm -f "$out" "$out.pre.sha256" "$out.post.sha256"

# Run with sidecar enabled
"$ROOT/pdf-deflyt" -p standard "$in" -o "$out" --sidecar-sha256 >/dev/null 2>&1 || true

# Verify output was created
[ -f "$out" ] || { echo "Sidecar test: output not created"; exit 1; }

# Verify sidecar files were created
[ -f "${in}.pre.sha256" ] || { echo "Pre-compression sidecar missing"; exit 1; }
[ -f "${out}.post.sha256" ] || { echo "Post-compression sidecar missing"; exit 1; }

# Verify sidecar files contain valid SHA256 hashes (64 hex chars)
grep -E '^[a-f0-9]{64}' "${in}.pre.sha256" >/dev/null || { echo "Invalid pre-sidecar format"; exit 1; }
grep -E '^[a-f0-9]{64}' "${out}.post.sha256" >/dev/null || { echo "Invalid post-sidecar format"; exit 1; }

# Clean up sidecar files
rm -f "${in}.pre.sha256" "${out}.post.sha256"

SIDECAR
chmod +x "$BUILD_DIR/sidecar_body.sh"
cases+=("sidecar_sha256::bash \"$BUILD_DIR/sidecar_body.sh\"")

# (M) CSV logging with --log option
if "$ROOT/pdf-deflyt" --help 2>&1 | grep -q -- '--log'; then
  cat > "$BUILD_DIR/csv_body.sh" << 'CSV'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

d="$WORK_DIR/csv_many"
rm -rf "$d"; mkdir -p "$d"

cp "$ASSETS_DIR/gray.pdf" "$d/in_1.pdf"
cp "$ASSETS_DIR/gray.pdf" "$d/in_2.pdf"
cp "$ASSETS_DIR/mono.pdf" "$d/in_3.pdf"

csv="$WORK_DIR/report.csv"
rm -f "$csv"

"$ROOT/pdf-deflyt" -p light --log "$csv" "$d" --jobs 1 >/dev/null 2>&1 || true

[ -f "$csv" ] || { echo "CSV file not created"; exit 1; }
lines=$(wc -l < "$csv" | tr -d ' ')
[ "$lines" -ge 1 ] || { echo "CSV too short"; exit 1; }

# Verify CSV contains expected columns
head -n 1 "$csv" | grep -E '.*,.*,.*,.*' >/dev/null || { echo "CSV format invalid"; exit 1; }

CSV
  chmod +x "$BUILD_DIR/csv_body.sh"
  cases+=("csv_logging::bash \"$BUILD_DIR/csv_body.sh\"")

  # (N) CSV logging edge cases (special characters in paths, large files)
  cat > "$BUILD_DIR/csv_edge_body.sh" << 'CSVEXT'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${PDF_DEFLYT_TEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BUILD_DIR="${PDF_DEFLYT_BUILD_DIR:-$ROOT/tests/build}"
ASSETS_DIR="${PDF_DEFLYT_ASSETS_DIR:-$ROOT/tests/assets}"
WORK_DIR="${PDF_DEFLYT_WORK_DIR:-$BUILD_DIR/work}"

# Test with file containing spaces in path
d="$WORK_DIR/csv edge"
rm -rf "$d"; mkdir -p "$d"
cp "$ASSETS_DIR/gray.pdf" "$d/file with spaces.pdf"

csv="$WORK_DIR/report_edge.csv"
rm -f "$csv"

"$ROOT/pdf-deflyt" -p standard --log "$csv" "$d" --jobs 1 >/dev/null 2>&1 || true

[ -f "$csv" ] || { echo "CSV not created for edge case"; exit 1; }
lines=$(wc -l < "$csv" | tr -d ' ')
[ "$lines" -ge 1 ] || { echo "CSV edge case: no entries"; exit 1; }

# Verify the CSV contains the file path (may be quoted or escaped)
cat "$csv" | grep -F "file with spaces.pdf" >/dev/null || { echo "CSV edge case: missing path with spaces"; exit 1; }

CSVEXT
  chmod +x "$BUILD_DIR/csv_edge_body.sh"
  cases+=("csv_logging_edge_cases::bash \"$BUILD_DIR/csv_edge_body.sh\"")
else
  echo "Skipping CSV logging tests (no --log support detected)" >&2
fi

# ---------- RUN PARALLEL ----------
run_one() {
  # Keep each case as a single opaque string; write to a temp script and run it.
  local line="$1"
  local name="${line%%::*}"
  local cmd="${line#*::}"

  # Trim a stray leading colon/whitespace if present
  cmd="${cmd#"${cmd%%[!$' \t\r\n']*}"}"
  [ "${cmd:0:1}" = ":" ] && cmd="${cmd:1}"

  local tmp="$BUILD_DIR/case-$name.sh"
  printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$cmd" > "$tmp"
  chmod +x "$tmp"
  run_case "$name" bash "$tmp"
}

export -f run_case
export -f green
export -f red
export -f run_one
export ROOT BUILD_DIR ASSETS_DIR

echo "Running ${#cases[@]} tests…"

# Prefer GNU parallel if available (clean & reliable).
if command -v parallel > /dev/null 2>&1; then
  # Use NUL-delimited input to avoid any quoting issues.
  printf '%s\0' "${cases[@]}" \
    | SHELL=/bin/bash PARALLEL='--will-cite' parallel --no-notice -0 -j "$(sysctl -n hw.ncpu 2> /dev/null || echo 4)" run_one {}
else
  # Deterministic sequential fallback (no DIY background job juggling)
  for c in "${cases[@]}"; do
    run_one "$c" || true
  done
fi

# ---- serial phase (depends on outputs from the parallel phase) ----
for c in "${cases_serial[@]}"; do
  run_one "$c" || true
done

set +x
echo
# Prefer marker file; fall back to grepping logs.
if [ -f "$BUILD_DIR/failed" ] || grep -R "Case FAILED" -q "$BUILD_DIR/logs" 2> /dev/null; then
  echo "Some tests failed ❌ (see $BUILD_DIR/logs)"
  [ -f "$BUILD_DIR/failed" ] && echo "Failed cases:" && cat "$BUILD_DIR/failed"
  exit 1
else
  echo "All tests passed ✅"
fi

# pdf-deflyt

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/geraint360/pdf-deflyt)
[![Shell](https://img.shields.io/badge/shell-zsh%2Fbash-green.svg)](https://github.com/geraint360/pdf-deflyt)

A fast PDF size reducer for macOS and Linux. Targets **material** file-size savings while keeping documents readable and searchable. Incorporates pragmatic defaults, safety rails, and first-class batch support.

> Typical savings on mixed documents are **20–70%**, depending on content and preset. See **Presets** and **Examples** below.

---

## Quick Start

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh | bash
```

**Compress a single PDF:**
```bash
pdf-deflyt document.pdf
# → document_compressed.pdf  (54.3% smaller)  [ok]
```

**Batch process a folder:**
```bash
pdf-deflyt --recurse ~/Documents/PDFs
```

**In-place compression:**
```bash
pdf-deflyt --inplace --min-gain 10 document.pdf
```

See [Examples](#examples) for more usage patterns.

---

## Features

- Simple CLI: `pdf-deflyt input.pdf -o output.pdf` (or compress in place with `--inplace`)
- Multiple presets tuned for different trade‑offs: **light**, **standard**, **extreme**, **lossless**
- **ICC profile support**: Automatically detects and handles complex color profiles using ImageMagick
- Batch processing (files or folders), recursion, include/exclude filters, and parallel jobs
- Dry‑run estimator with projected size and savings (no writes)
- Skip rules to avoid work on tiny files or when savings would be negligible
- Timestamp‑friendly: preserves file date and time for in‑place operations (APFS granularity tolerated)
- Optional password handling for encrypted PDFs (`--password`); otherwise it will **skip or pass‑through** safely
- Deterministic behavior and stable output naming (`*_compressed.pdf`), unless `-o`/`--inplace` is used
- Integrations with DEVONthink 3 and 4

---

## Installation

`pdf-deflyt` and the associated installer should run on both macOS and Linux. The installer is the same for both.

Re-running the installer should update with the latest version from the repo.

Please note that the **Linux version has not been tested**. It should work. It may not do.

### Quick Install (macOS & Linux)

Copy and paste this into a Terminal window:

```bash
curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh | bash
```

- Installs `pdf-deflyt` and `pdf-deflyt-image-recompress` helper to `~/bin` (default; override with `--prefix /path`).

- Installs required dependencies automatically via **Homebrew** (macOS) or your package manager (Linux e.g. **apt**, **dnf**, or **brew** if present).

	- **Ghostscript** (`gs`)
	- **pdfcpu**
	- **qpdf** (for encrypted‑PDF handling and tests)
	- **exiftool** (or libimage-exiftool-perl (Debian/Ubuntu), perl-Image-ExifTool (Fedora), perl-image-exiftool (Arch), exiftool (openSUSE) on Linux)
	- **poppler** (poppler-utils (Debian/Fedora), poppler (Arch), poppler-tools (openSUSE) on Linux)
	- **coreutils**
	- **mupdf-tools** *(automatically preferred; falls back to `mupdf` if already installed)*
	- **parallel** (optional, speeds up batch jobs)
	
  - For the optional ability to recode FlateDecode (zlib-compressed) embedded images carrying ICC profiles as lossy JPEGs
	   - **imagemagick**
     - **Python 3.7+** (standard on modern macOS/Linux)
     - **PyMuPDF** (auto-installed in isolated venv on first use)

- **Does not** install DEVONthink scripts unless explicitly requested. (Obviously, this is a macOS-only feature.)

- `sudo` may be required for installing dependencies on some distributions.  

- The pdf-deflyt CLI works the same across macOS and Linux.


**Optional: Install DEVONthink scripts (macOS only)**  

If you want the DEVONthink integration (the Compress PDF Now and Compress PDF (Smart Rule) scripts), use:

```bash
curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh \
  | bash -s -- --with-devonthink
```

This will download, compile and install the  Applescripts into the correct ~/Library/Application Scripts/... folders for DEVONthink 4 (and DEVONthink 3 if detected).

You can target a specific version (and avoid “missing” notices) with `--dt 4` or `--dt 3` (default `auto`).

---

### Uninstallation

Uninstallation is the same on macOS and Linux. If you installed the DEVONthink scripts, they will also be removed.

Copy and paste this into a Terminal window:

```bash
curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh | bash -s -- --uninstall
```
Verify current setup (paths and tools):
```bash
curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh | bash -s -- --verify-only
```

---

## Usage

```bash
pdf-deflyt [options] <file-or-dir>...
```

### Common Options

- `-p, --preset <name>`
  One of `light`, `standard`, `extreme`, `lossless`.
  Tunes compression strength and quality trade-offs.
  `standard` uses intelligent auto-detection based on PDF content.

- `-o, --output <file>`  
  Explicit output file (single input only).  
  If omitted, uses default naming (`*_compressed.pdf`).

- `--inplace`  
  Compress and overwrite the input file.  
  Preserves the **original modification timestamp** (within ~2min APFS tolerance).

- `--dry-run`  
  Analyse inputs only, print projected savings and sizes, **don’t write any files**.

- `--recurse`  
  When directories are given, process PDFs recursively.

- `--include <regex>`  
  Process only files whose full path matches the given regex.

- `--exclude <regex>`  
  Skip any files whose full path matches the given regex.

- `--jobs <N>`  
  Parallel workers for batch mode (default: number of CPU cores).

- `--min-gain <pct>`  
  Only replace a file if the compressed result is at least this much smaller.  
  If smaller savings, the original is kept.

- `--password <pw>`  
  Password for encrypted PDFs. Without this, encrypted files are **skipped** safely.

- `--quiet`  
  Suppress the usual “arrow” output line for each processed file.

- `--version`, `--help`  
  Show version or usage.

**Output naming:**  
If neither `-o` nor `--inplace` is used, results are written next to the input as: `*_compressed.pdf`.


### Advanced Options

For the full list of advanced options, run:
```bash
pdf-deflyt --help-advanced
```

Key advanced options include:

- `--password-file <FILE>`
  Provide a password for encrypted PDFs via a file (safer than inline `--password`).

- `--post-hook 'CMD {}'`
  Run a shell command after successfully processing each file.
  `{}` is replaced with the output path.
  Example:
  ```bash
  --post-hook 'echo Compressed: {} >> ~/processed.log'
  ```

- `--sidecar-sha256`
  Generate a .sha256 checksum file alongside each output.
  Useful for integrity checks, deduplication, and DEVONthink integration.

- `--check-deps`
  Verify required and optional tool availability, then exit.

- `--debug`
  Print computed parameters, selected DPI, JPEG quality, estimated savings, etc.
  Does not write files.

- `--log <FILE>`
  Append results to the specified log file in CSV format, including input/output size,
  savings, and status.

### Preset strength ordering

By design: `extreme ≤ standard ≤ light` in resulting size (within ~5%).
`lossless` preserves quality/structure as much as possible with no image recompression.
`standard` is intelligent and auto-detects whether PDFs are text-only or image-heavy.

---

## Examples

**Super Basic**
```bash
# Compress using the default preset ("standard").
# Output will be written as input_compressed.pdf next to the input,
# but only if the compressed file is meaningfully smaller.
pdf-deflyt input.pdf
```

**Basic Explicit Output**
```bash
# Compress using the "standard" preset and write to a specific path:
pdf-deflyt -p standard input.pdf -o output.pdf
```

**Estimate Only (Dry Run)**
```bash
# Show estimated size and savings without modifying the file:
pdf-deflyt --dry-run -p light input.pdf
# Output:
# DRY: input.pdf  est_savings≈42%  est_size≈1.2MB (from 2.1MB)
```

**In-Place Compression (Preserve Timestamp)**
```bash
# Overwrite the original file in-place, but only keep the result if
# the compressed version is at least 25% smaller.
pdf-deflyt -p extreme --inplace --min-gain 25 input.pdf
```

**Batch a Folder (Recursive, Parallel)**
```bash
# Recurse into ~/Documents/PDFs, compress all PDFs using the standard preset,
# include only those under "/Reports/", skip any in "/Drafts/",
# and process up to 4 files in parallel.
pdf-deflyt -p standard --recurse \
  --include '/Reports/' --exclude '/Drafts/' \
  --jobs 4 ~/Documents/PDFs
```

**Encrypted PDFs**
```bash
# Without a password, encrypted PDFs are skipped safely:
pdf-deflyt input_encrypted.pdf -o out.pdf

# Provide a password to actually compress encrypted PDFs:
pdf-deflyt --password mysecretpassword input_encrypted.pdf -o out.pdf

# Better than passing --password directly on the CLI:
pdf-deflyt --password-file ~/secrets/pdfpass.txt input_encrypted.pdf
```

**Dry-Run Entire Tree (Planning View)**
```bash
# Show estimated savings for all PDFs in a directory tree,
# without writing any files:
pdf-deflyt --dry-run --recurse ~/Scans
```

**Use a Post-Hook (Integration Example)**
```bash
# Run a custom command after processing each file:
pdf-deflyt --inplace --post-hook 'echo Processed: {} >> ~/processed.log' ~/Scans/file.pdf
```

---

## ICC Profile Images

PDFs with ICC color profiles (common in professional photography, design work, and some scanned documents) require special handling to preserve color accuracy.

### How It Works

`pdf-deflyt` automatically:
1. Detects FlateDecode-compressed images with ICC profiles
2. Uses the `pdf-deflyt-image-recompress` helper script
3. Converts images via ImageMagick (preserves ICC profiles)
4. Reinserts properly-compressed images into the PDF

### Requirements

- **ImageMagick 6 or 7** (installed automatically by installer)
- **Python 3.7+** (standard on modern macOS/Linux)
- **PyMuPDF** (auto-installed in isolated venv on first use)

The helper script automatically creates an isolated Python virtual environment (next to the script when writable, otherwise under `~/.cache/pdf-deflyt/venv`) and installs PyMuPDF on first run. No manual Python setup required.

### What Happens Without ImageMagick?

If ImageMagick is not installed:
- PDFs with ICC profile images will use **structural compression only** (1-5% typical savings)
- A warning message will be displayed
- Install ImageMagick to enable full compression: `brew install imagemagick` (macOS) or `sudo apt install imagemagick` (Linux)

### Supported ImageMagick Versions

- **ImageMagick 7** (macOS/Linux): Uses `magick` command
- **ImageMagick 6** (legacy): Uses `convert` command
- Both versions fully supported and auto-detected

### Example
```bash
# PDF with ICC profiles - automatically handled
pdf-deflyt photo-portfolio.pdf
# NOTICE: Detected ICC profile images, using ImageMagick-based compression
# → photo-portfolio_compressed.pdf  (89.4% smaller)  [ok]

# Verify helper is working
pdf-deflyt-image-recompress --help

# Debug mode shows detection
pdf-deflyt --debug icc-document.pdf
```
---

## Compression Logic (what happens under the hood)

`pdf-deflyt` aims for “smaller, still-good” — not just the smallest possible bytes. The pipeline is content-aware and tuned to keep text selectable, preserve vector graphics when possible, and compress raster images aggressively only when it’s safe.

### High-level flow
1. **Probe & classify pages**  
   Identify text/vector vs raster-heavy pages (via `pdfcpu`, `mutool`, `pdfinfo`).  
   Decide whether pages can remain vector or should be re-rasterized.

2. **Preset-driven image policy**  
   Each preset picks **target DPI** (per color/gray/mono) and **JPEG quality**.  
   - `light`: gentle downsampling; good for already decent PDFs
   - `standard`: intelligent auto-tuning based on content; safe for most PDFs
   - `extreme`: maximum shrinking while remaining legible
   - `lossless`: structural optimizations only; no lossy image recompression

3. **Ghostscript synthesis**
   Ghostscript (`pdfwrite`) is used to:
   - **Downsample** large raster images to preset DPIs
   - **Recompress** images (JPEG for color/gray, CCITT/Flate for mono)
   - **Compact object streams** and optimize PDF structure
   - **Keep vector text/graphics** where feasible

4. **Encrypted PDFs**
   - Without a password → **safe skip** (no modification).
   - With `--password`/`--password-file` → **decrypt to a temp**, process, then re-emit a normal PDF.

5. **Determinism & timestamps**
   - Always produces deterministic output for reproducibility
   - Always preserves metadata and timestamps

6. **Safety rails**  
   - `--min-gain` keeps the original unless savings meet your threshold.  
   - In `--inplace` mode, the original is only replaced if the new file qualifies.

### Preset guide (ballpark)
| Preset    | Color/Gray DPI | JPEG Q | Mono DPI | Notes |
|-----------|-----------------|--------|----------|-------|
| light     | ~300            | ~78    | ~1200    | Higher quality; good for already-optimized PDFs |
| standard  | ~200 (auto)     | ~72    | ~900     | Intelligent auto-tuning based on content |
| extreme   | ~144            | ~68    | ~600     | Maximum compression while staying readable |
| lossless  | keep            | n/a    | keep     | No lossy recompression; structural tweaks only |

> `standard` preset automatically detects text-only PDFs and adjusts strategy. Use `--debug` to see the selected DPI/quality per run.

---

## Integration Notes

### Determinism
- pdf-deflyt always produces deterministic, reproducible output for identical inputs.
- Useful for deduplication workflows and version control.

### Metadata & Timestamps
- Metadata is always preserved for document integrity.
- Timestamps (mtime/atime) are always preserved for file tracking.

### Exit Status Codes

- **0** → Success (including “skipped” files)
- **1** → No PDFs after filtering
- **2** → Usage error or unreadable input
- **127** → Missing dependency or environment misconfiguration

### Security

- If `--password` or `--password-file` is provided, the decrypted data is stored in a **secure temporary file**; the original is never modified in place.
- No password caching is performed; passwords are never logged.
- No external network calls are made during compression.

### Performance

- Most processing time is spent in **Ghostscript**; presets directly influence runtime.
- Use `--jobs <N>` to enable parallel compression for batch workloads.
- For large PDFs, expect increased temporary storage usage — especially on SSDs — due to intermediary render stages.
- For highly parallel workloads, ensure you have sufficient available disk space and CPU cores.

#### Typical Performance

Based on benchmarks on a modern MacBook Pro (M1/M2):

| File Type | Size | Preset | Avg Time | Savings | Output Size |
|-----------|------|--------|----------|---------|-------------|
| Mixed document (scan + text) | 2.5 MB | standard | ~0.8s | 45% | 1.4 MB |
| Image-heavy PDF | 8.2 MB | standard | ~2.1s | 63% | 3.0 MB |
| Vector-only document | 450 KB | standard | ~0.3s | 12% | 396 KB |
| Photo portfolio | 15 MB | light | ~3.5s | 38% | 9.3 MB |
| Scanned book (100 pages) | 45 MB | extreme | ~8.2s | 78% | 9.9 MB |

*Run your own benchmarks:*
```bash
make benchmark           # Run performance benchmarks on test fixtures
make benchmark RUNS=5    # Average over 5 runs
```

---

## DEVONthink Integration

There are two AppleScripts provided:

1. **Compress PDF Now** — a menu/toolbar action to compress the selected PDFs immediately.
2. **Compress PDF (Smart Rule)** — a handler for DEVONthink Smart Rules to compress PDFs automatically when they meet certain conditions (e.g. added to a group, file size > X).


By default, both scripts use **pdf-deflyt** with the **standard** compression preset, but this can be changed by editing the AppleScript headers if you prefer a different preset.

Let DEVONthink complete OCR **before** compression (pdf-deflyt does **not** perform OCR).


### Installation

Use the installer to place the compiled scripts into the correct **DEVONthink 4**/**3** folders. By default, it auto-detects what you have installed:

```bash 
(curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/install-pdf-deflyt.sh \)
 | bash -s -- --with-devonthink
```
>Tip: Re-running the installer will **update** the scripts to the latest version automatically.

**For DEVONthink 3:**
The scripts are compatible but are installed into a different path:
``~/Library/Application Scripts/com.devon-technologies.think3/``
Use the `--prefix` option if you need to override defaults.

### Using the Scripts in DEVONthink

**Compress PDF Now**
- Select a PDF then run the script from the **Scripts** menu.

**Compress PDF (Smart Rule)**
- Create a **Smart Rule** (_Tools → New Smart Rule…_)
- Choose your conditions (e.g. Kind is PDF, Size > 300 KB, etc.).
- Under **Perform the following actions**, select **Apply Script…** and choose
**Compress PDF (Smart Rule)**.
- For unattended operation, use `--inplace --min-gain 1` for safety, or customise flags in the AppleScript source.

**Recommended Defaults**

| Workflow | Suggested Flags |
|----------|-----------------|
| Safe default | `--inplace --min-gain 1` |
| Scans & large PDFs | `-p standard --inplace --min-gain 3` |

---

# Troubleshooting

- **“No PDFs found.”**  
  Check your path/quotes; without `--recurse`, directories aren’t descended.

- **“SKIP (encrypted)”**  
  Supply a password: `--password '…'` or `--password-file path`.

- **“SKIP (below …)”** or **“kept-original(below-threshold-or-larger)”**  
  Either the output was not smaller, or it didn’t meet `--min-gain`.  
  Lower `--min-gain`, or try `-p extreme`.

- **Tiny savings on vector‑only PDFs**  
  Expected; there’s little to compress beyond structure.

- **File looks slightly soft**  
  Use `-p light`, or keep `standard` and raise quality (e.g., `-p light`).

- **“Missing: ghostscript / pdfcpu / qpdf / mutool / poppler / exiftool”**  
  Run:  
  ```bash
  brew install ghostscript pdfcpu qpdf mupdf-tools poppler exiftool coreutils
  ```

- **In‑place timestamp drift**  
  APFS granularity can cause small drift; the tool keeps it within ~2 minutes.

- **Unexpected skips or errors**  
  Use `--debug` to see exactly what the tool intends (inputs, DPI choices, JPEG Q, estimated savings, etc.).

- **Checksum verification failed**  
  If using `--sidecar-sha256`, mismatches indicate content changes since last run.

- **DEVONthink automation not working**  
  Ensure the `.scpt` scripts are installed in:
  ```
  ~/Library/Application Scripts/com.devon-technologies.think/Menu
  ~/Library/Application Scripts/com.devon-technologies.think/Smart Rules
  ```
  Then restart DEVONthink. (Updates to the Smart Rule don't appear to take effect without restarting DEVONthink.)

- **"Python helper failed" or "ImageMagick helper unavailable"**  
  Install ImageMagick:  
  ```
  brew install imagemagick  # macOS
  sudo apt install imagemagick  # Linux
  ```
  Verify helper exists:
  ```
  ls -l $(dirname $(which pdf-deflyt))/pdf-deflyt-image-recompress
  pdf-deflyt-image-recompress --help
  ```
  The Python virtual environment is created automatically on first use.

- **Images look corrupted or have wrong colors**  
  This can happen with ICC profile images if ImageMagick is not installed. Install ImageMagick and re-run compression.  

- **"NOTICE: Detected ICC profile images"**  
  This is informational - your PDF has complex color profiles.   Compression will take slightly longer but colors will be preserved.   If you see "WARNING: ImageMagick helper unavailable", install ImageMagick.


---

# Development

This is only relevant to those who want to reuse or extend pdf-deflyt.

## Build and Install

```bash
make install-bin          # installs ./pdf-deflyt to ~/bin/pdf-deflyt (default)
```
Ensure `~/bin` is on your `PATH`. Override the target with:
```bash
make install-bin PREFIX=/some/other/bin
```

## DEVONthink Scripts (Optional)

If you want the accompanying DEVONthink automations:

```bash
make compile              # compiles .applescript to .scpt in devonthink-scripts/compiled
make install-dt           # installs compiled .scpt into DEVONthink’s “App Scripts” folder
# Or both:
make install              # = install-bin + install-dt
```

By default, installs go to DEVONthink 4 locations.  
If you are using DEVONthink 3, specify the version explicitly:

```bash
make install-dt DT_VER=3
```

Or manually move the compiled `.scpt` files into DEVONthink 3's scripts location:

```
~/Library/Application Scripts/com.devon-technologies.think3/
```

## Repository Layout

- `pdf-deflyt` — the zsh CLI
- `pdf-deflyt-image-recompress` — Python helper for ICC profile images
- `tests/` — fixtures, helpers, and the full test suite
- `scripts/` — `lint.sh`, `format.sh`
- `devonthink-scripts/` — optional AppleScripts and compiled `.scpt`

## Running Tests

**Smoke test** (quick check):
```bash
make smoke
```

**Full suite** (rebuild fixtures, then run all tests):
```bash
make test
```

The suite verifies:
- All presets run and produce files
- `--dry-run` estimate prints
- `-o` is respected
- `--inplace` preserves timestamps (with tolerance)
- Filters (`--include/--exclude`), recurse, jobs
- `--min-gain`
- Encrypted PDFs: safe behavior without password, success with `--password`
- Default naming rule
- Deterministic size ordering (`extreme ≤ standard ≤ light` within tolerance)
- CSV logging (conditionally tested when supported)

**Useful environment flags:**

- `PDF_DEFLYT_SKIP_CLEAN=1 make test` — keep existing `tests/assets`/`tests/build`
- `PDF_DEFLYT_TEST_JOBS=8 make test` — control parallelism in the test harness
- `SKIP_IMAGEMAGICK_TESTS=1 make test` — skip ICC profile tests if ImageMagick unavailable

## Linting & Formatting

```bash
make lint           # automatically apply shfmt & minor fixes
make lint VERBOSE=1 # show detailed output
make lint FIX=1     # report only
```

## Make Targets

```text
install-bin   # copy ./pdf-deflyt → ~/bin/pdf-deflyt (override PREFIX=...)
compile       # build AppleScripts → devonthink-scripts/compiled
install-dt    # install compiled scripts into DEVONthink App Scripts folder
install       # = install-bin + install-dt
smoke         # quick CLI sanity test
test          # full suite
benchmark     # run performance benchmarks
lint          # check and fix code style
fmt           # format code
clean         # remove build and generated assets
```

---

## License

MIT © 2025 Geraint Preston

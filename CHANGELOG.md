# Changelog

All notable changes to pdf-deflyt will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.5.1] - 2026-10-24

### Fixed
- Linux: the system `/usr/bin/python3` was ignored (a macOS-only Xcode check applied
  everywhere), which silently disabled the metadata restore, feature and text checks
  and the lossless JPEG/JBIG2 passes
- `make benchmark` failed immediately (`in` is a reserved word in awk), its summary
  included the progress lines, and `RUNS=N` was ignored

### Changed
- README: removed the "Typical Performance" table, whose figures could not be
  reproduced, in favour of measured per-file overhead and `make benchmark`

## [2.5.0] - 2026-10-24

### Added
- Lossless JPEG optimization: JPEG streams are re-encoded with optimized Huffman tables
  (`jpegtran`, from jpeg-turbo); pixels are unchanged and only smaller results are kept
- Lossless JBIG2 for 1-bit scans (`jbig2enc`, generic region mode only): typically 30–50%
  smaller than CCITT G4, with every converted image decoded and verified pixel-exact.
  Rendering was checked in MuPDF, Poppler, Ghostscript and PDFKit (DEVONthink, Preview)
- Feature-survival check: a candidate is rejected if it loses form fields or their values,
  annotations or links, bookmarks, attachments or pages
- Text-layer check: a candidate is rejected if fewer than 97% of the original's words
  survive (protects OCR layers)
- `--timeout SECS` (default 600): bounds every external tool call
- Documents with form fields also get the in-place image recompression candidate, so they
  still shrink when the Ghostscript result is rejected (81.7% on the form test fixture)
- `jpegtran` and `jbig2` are reported by `--check-deps`; the installer installs them
  (best effort)

### Changed
- The original Info dictionary and XMP metadata are restored verbatim on every output
  (previously creation/modification dates and some fields were rewritten)
- Digitally signed PDFs are left byte-for-byte untouched instead of being rewritten,
  which invalidated their signatures
- The visual check now samples up to 5 pages across the whole document instead of only
  the first pages

### Fixed
- Ghostscript results silently dropped form fields and their values, and rewrote dates

## [2.4.0] - 2026-10-24

### Fixed
- Works with pdfcpu 0.16+: the removed `-quiet` flag, the mandatory config migration
  and the refusal to overwrite existing files made every structural pass fail silently
- Batches of two or more files: the file list was joined into one bogus path
- `--jobs N` parallel mode: workers received no file and ignored all options
  (preset, `--inplace`, `--log`, ...); a batch summary is now printed in parallel mode too
- `--memory-limit` crashed (`parse_bytes` was called before it was defined)
- `--debug` captured its own log line into the temp-directory path
- In-place compression lost the original's modification time and set permissions to 600;
  it now keeps mode, extended attributes (e.g. Finder tags) and timestamps, and writes atomically
- Concurrent runs that only read the same input (e.g. `-o` to different files) were
  skipped as "locked"; locks are now taken on the destination
- Non-PDF input "succeeded" and was copied to the output; it now fails with exit status 1
- Batch summary never printed (awk syntax error); exit status is now 1 when any file fails
- `--` dropped every argument after it; `-p/-o` long forms `--preset/--output` now work
- Dry-run used different JPEG targets from the real run
- DEVONthink scripts: shared temp output between concurrent runs, and successful
  replacements logged as failures (`r` was not passed to `runCompression`)
- Test runner: a failure in the parallel phase silently skipped every serial test

### Changed
- Compression is now candidate-based: structural, Ghostscript and (for ICC images) the
  ImageMagick helper are all tried, each result is finalized with pdfcpu/mutool/qpdf, and
  the smallest one that keeps the page count and passes a low-resolution visual
  comparison is used
- A single low-resolution image no longer disables image recompression for the whole
  document (a typical letterhead-logo + photo PDF went from 0% to ~92% savings)
- ICC profile images: when the helper is unavailable, Ghostscript (which keeps the ICC
  colour space) is used instead of falling back to structural-only compression
- ICC helper replaces images in place (`replace_image`) instead of delete + reinsert,
  which left a 1×1 placeholder image on every page
- `--jobs` defaults to the number of CPU cores, as documented
- `--log` writes a header row and quotes paths containing commas or quotes
- Added `-q/--quality N` to override the preset's JPEG quality
- Removed the per-file analysis cache (it was keyed on temp paths and never hit)

### Added
- Two-tier help system (`--help` for common options, `--help-advanced` for expert features)
- Automatic algorithm selection based on PDF content (images vs text-only)
- Detection of already-optimized PDFs to avoid unnecessary processing
- Text-only PDF optimization using Ghostscript font compression
- Progress indicators for batch processing jobs
- Improved error messages with better formatting
- Test coverage for ICC profile image handling
- CI/CD runs automatically on push and pull requests
- More comprehensive .gitignore entries for test artifacts and Python files

### Changed
- Simplified parameter set from 32 to ~22 by removing redundant options
- Metadata preservation, timestamp preservation, and deterministic output are now always enabled (no longer configurable)
- Presets reduced from 6 to 4: `light`, `standard`, `extreme`, `lossless` (removed `archive` and `aggressive`)
- Help output simplified to focus on most common use cases (~15 parameters)
- `standard` preset now auto-tunes based on content analysis
- Temp files now use secure `mktemp` with restricted permissions (600)
- Improved security for encrypted PDF handling

### Removed
- `-q` flag for JPEG quality override (quality now auto-tuned per preset)
- `--linearize` flag (removed due to 5-15% overhead with minimal benefit)
- `--keep-metadata` / `--strip-metadata` flags (metadata always preserved)
- `--keep-date` / `--no-keep-date` flags (timestamps always preserved)
- `--deterministic` / `--no-deterministic` flags (output always deterministic)
- `archive` and `aggressive` presets (redundant with `standard` and `extreme`)

### Fixed
- Text-only PDFs no longer get bigger during compression
- Images with transparency (soft masks) are now properly preserved
- MuPDF xref errors fixed with qpdf repair step before ICC processing
- ICC profile images now properly downsampled according to preset DPI targets
- Already-JPEG images are now recompressed when beneficial (previously skipped)
- Makefile `uninstall-dt` target now uses correct variable names (DT_MENU/DT_RULES)

## [2.3.0-zsh] - 2025-01-XX

### Added
- Auto-tuned compression via image PPI analysis
- Multiple presets: light, standard, extreme, lossless
- Batch processing with recursion and parallel execution
- Special handling for ICC profile images via ImageMagick
- Metadata and timestamp preservation by default
- DEVONthink integration scripts
- Comprehensive test suite
- Dry-run mode for estimating savings
- Password support for encrypted PDFs
- Filtering with include/exclude regex patterns
- Post-processing hooks
- SHA256 sidecar file generation
- CSV logging support

### Changed
- Complete rewrite in zsh for better macOS integration
- Improved cross-platform support (macOS and Linux)

### Security
- Safe handling of encrypted PDFs
- No password caching or logging

## Earlier Versions

Earlier versions were internal development releases.

[Unreleased]: https://github.com/geraint360/pdf-deflyt/compare/v2.3.0...HEAD
[2.3.0-zsh]: https://github.com/geraint360/pdf-deflyt/releases/tag/v2.3.0

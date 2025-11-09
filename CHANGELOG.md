# Changelog

All notable changes to pdf-deflyt will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

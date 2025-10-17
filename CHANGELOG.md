# Changelog

All notable changes to pdf-deflyt will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Progress indicators for batch processing jobs
- Improved error messages with better formatting
- Test coverage for ICC profile image handling
- CI/CD runs automatically on push and pull requests
- More comprehensive .gitignore entries for test artifacts and Python files

### Changed
- Temp files now use secure `mktemp` with restricted permissions (600)
- Improved security for encrypted PDF handling

### Fixed
- Makefile `uninstall-dt` target now uses correct variable names (DT_MENU/DT_RULES)

## [2.3.0-zsh] - 2025-01-XX

### Added
- Auto-tuned compression via image PPI analysis
- Multiple presets: light, standard, extreme, aggressive, lossless, archive
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

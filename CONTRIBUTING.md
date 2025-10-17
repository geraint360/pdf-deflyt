# Contributing to pdf-deflyt

Thank you for considering contributing to pdf-deflyt! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, constructive, and professional in all interactions.

## How to Contribute

### Reporting Bugs

Before creating a bug report:
- Check existing [issues](https://github.com/geraint360/pdf-deflyt/issues)
- Test with the latest version
- Verify dependencies are correctly installed (`pdf-deflyt --check-deps`)

Include in your bug report:
- OS version (macOS/Linux distro)
- pdf-deflyt version (`pdf-deflyt --version`)
- Exact command used
- Expected vs actual behavior
- Relevant log output (use `--debug` flag)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:
- Use a clear, descriptive title
- Provide detailed explanation of the proposed feature
- Explain why this enhancement would be useful
- Include examples if applicable

### Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/pdf-deflyt.git
   cd pdf-deflyt
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the coding style (see below)
   - Add tests for new functionality
   - Update documentation as needed

4. **Test your changes**
   ```bash
   make lint          # Check code style
   make smoke         # Quick smoke test
   make test          # Full test suite
   ```

5. **Commit with clear messages**
   ```bash
   git commit -m "feat: add support for XYZ"
   ```

   Use conventional commit format:
   - `feat:` new feature
   - `fix:` bug fix
   - `docs:` documentation changes
   - `test:` adding/updating tests
   - `refactor:` code refactoring
   - `perf:` performance improvements
   - `chore:` maintenance tasks

6. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create a pull request on GitHub.

## Development Setup

### Prerequisites

```bash
# macOS
brew install ghostscript pdfcpu qpdf mupdf-tools exiftool poppler coreutils imagemagick parallel

# Linux (Debian/Ubuntu)
sudo apt-get install ghostscript parallel poppler-utils exiftool imagemagick python3
# Install pdfcpu, qpdf, mupdf separately (see README)
```

### Running Tests

```bash
# Quick health check
make smoke

# Full suite
make test

# Keep test artifacts for debugging
PDF_DEFLYT_SKIP_CLEAN=1 make test

# Run specific number of parallel jobs
PDF_DEFLYT_TEST_JOBS=8 make test
```

### Code Style

#### Shell Scripts (Zsh/Bash)

- Use 2-space indentation
- Prefer `[[  ]]` over `[  ]` for conditionals
- Quote variables: `"$VAR"` not `$VAR`
- Use descriptive variable names in CAPS for globals, lowercase for locals
- Add comments for complex logic
- Run `make lint` before committing

Example:
```zsh
process_file() {
  local input="$1"
  local output="${2:-}"

  # Validate input
  [[ -r "$input" ]] || { echo "ERROR: Cannot read $input" >&2; return 1; }

  # Process
  do_work "$input" "$output"
}
```

#### Python Scripts

- Follow PEP 8 style guide
- Use 4-space indentation
- Include docstrings for functions
- Type hints where helpful

### Project Structure

```
pdf-deflyt/
├── pdf-deflyt                    # Main CLI script (zsh)
├── pdf-deflyt-image-recompress   # Python helper for ICC profiles
├── tests/
│   ├── run.sh                    # Main test suite
│   ├── fixtures.sh               # Test fixture generation
│   ├── helpers.sh                # Test utilities
│   └── smoke.sh                  # Quick smoke tests
├── scripts/
│   ├── install-pdf-deflyt.sh    # Installation script
│   ├── lint.sh                   # Linting script
│   └── format.sh                 # Code formatting
├── devonthink-scripts/           # DEVONthink integration
│   └── src/                      # AppleScript sources
├── Makefile                      # Build and test automation
└── README.md                     # User documentation
```

### Testing Guidelines

- Add tests for all new features
- Ensure existing tests pass
- Test on both macOS and Linux if possible
- Include edge cases in tests
- Keep tests fast (use small test PDFs)

### Documentation

- Update README.md for user-facing changes
- Add inline comments for complex code
- Update CHANGELOG.md following Keep a Changelog format
- Include usage examples for new features

## Release Process

Maintainers follow this process:

1. Update version in `pdf-deflyt` and `package.json`
2. Update CHANGELOG.md
3. Run full test suite
4. Create git tag: `git tag v2.x.x`
5. Push tag: `git push origin v2.x.x`
6. Create GitHub release with changelog

## Questions?

Open an issue for discussion or clarification.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

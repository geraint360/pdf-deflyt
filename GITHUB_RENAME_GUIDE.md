# GitHub Repository Rename Guide

This guide documents the process of renaming the GitHub repository from `pdf-squeeze` to `pdf-deflyt`.

## Repository Information

- **Current Repository**: `https://github.com/geraint360/pdf-squeeze`
- **New Repository Name**: `pdf-deflyt`
- **New Repository URL**: `https://github.com/geraint360/pdf-deflyt`

## What Has Been Renamed

### Local Changes (Already Complete)

All local files and references have been updated from `pdf-squeeze` to `pdf-deflyt`:

#### Main pdf-deflyt Project (`~/Developer/pdf-squeeze/`)
- ✅ Main script: `pdf-squeeze` → `pdf-deflyt`
- ✅ Helper script: `pdf-squeeze-image-recompress` → `pdf-deflyt-image-recompress`
- ✅ All internal references within scripts
- ✅ `README.md` - all documentation updated
- ✅ `CLAUDE.md` - project guidance updated
- ✅ `Makefile` - build targets and installation paths updated
- ✅ Installer script: `install-pdf-squeeze.sh` → `install-pdf-deflyt.sh`
- ✅ All script references updated
- ✅ DEVONthink AppleScripts renamed and updated:
  - `PDF Squeeze (Smart Rule).applescript` → `PDF Deflyt (Smart Rule).applescript`
  - All internal script references updated
- ✅ Output file naming: `*_squeezed.pdf` → `*_deflyt.pdf`
- ✅ Temp file prefixes: `pdfsqueeze` → `pdfdeflyt`
- ✅ Python venv directory: `.pdf-squeeze-venv` → `.pdf-deflyt-venv`

#### Deflyt Mac App (`~/Developer/Deflyt/`)
- ✅ Service class: `PDFSqueezeService` → `PDFDeflytService`
- ✅ Service file: `PDFSqueezeService.swift` → `PDFDeflytService.swift`
- ✅ All Swift files updated to reference `PDFDeflytService`
- ✅ All references to `pdf-squeeze` command changed to `pdf-deflyt`
- ✅ Documentation files updated:
  - `README.md`
  - `BUILDING.md`
  - `PROJECT_SUMMARY.md`
  - `.claude/CLAUDE.md`

#### Test Files (Still Pending)
- ⏳ Test suite in `tests/` directory
- ⏳ Test fixtures and scripts

## GitHub Repository Rename Steps

### Step 1: Rename Repository on GitHub

1. Go to `https://github.com/geraint360/pdf-squeeze`
2. Click **Settings** tab
3. Scroll down to **Repository name**
4. Change name from `pdf-squeeze` to `pdf-deflyt`
5. Click **Rename**

**Important**: GitHub automatically redirects the old URL to the new one, so existing clones will continue to work temporarily.

### Step 2: Update Local Git Remote

After renaming on GitHub, update your local repository:

```bash
cd ~/Developer/pdf-squeeze
git remote set-url origin https://github.com/geraint360/pdf-deflyt.git

# Verify the change
git remote -v

# Should show:
# origin  https://github.com/geraint360/pdf-deflyt.git (fetch)
# origin  https://github.com/geraint360/pdf-deflyt.git (push)
```

### Step 3: Rename Local Directory (Optional)

To match the repository name:

```bash
cd ~/Developer
mv pdf-squeeze pdf-deflyt
cd pdf-deflyt
```

**Note**: If you rename the directory, you'll need to update:
- Any absolute paths in your shell configuration
- Bookmarks/shortcuts to the project
- IDE/editor workspace configurations

### Step 4: Commit and Push Changes

```bash
cd ~/Developer/pdf-deflyt  # or pdf-squeeze if you didn't rename
git add -A
git commit -m "Rename project from pdf-squeeze to pdf-deflyt

- Renamed main script and helper script
- Updated all internal references and documentation
- Updated Makefile, installer, and build scripts
- Renamed DEVONthink AppleScripts
- Updated Deflyt Mac app to reference pdf-deflyt
- Changed output file naming from *_squeezed.pdf to *_deflyt.pdf

This is a complete project rename with no functional changes to compression logic."

git push origin main
```

### Step 5: Update Documentation URLs

After the rename, update any documentation that references the old URL:

1. **README.md** installer URLs (already done):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh | bash
   ```

2. **Issue templates** (if any)
3. **Project website/documentation** (if any)
4. **Social media links** (if shared publicly)

### Step 6: Create GitHub Release (Optional)

Consider creating a release to mark this major change:

```bash
git tag -a v2.4.0 -m "Release v2.4.0: Project renamed from pdf-squeeze to pdf-deflyt"
git push origin v2.4.0
```

Then create a GitHub release with release notes explaining the rename.

## Important Notes

### Backward Compatibility

**The rename breaks backward compatibility** for:

1. **Installation commands**: Users with old instructions will need to update
2. **Installed binaries**: Existing users have `pdf-squeeze` in `~/bin`, not `pdf-deflyt`
3. **Documentation links**: Old URLs will redirect but should be updated

### Migration Path for Users

Users who have `pdf-squeeze` installed can migrate:

```bash
# Uninstall old version
rm -f ~/bin/pdf-squeeze ~/bin/pdf-squeeze-image-recompress
rm -rf ~/bin/.pdf-squeeze-venv

# Install new version
curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh | bash
```

Or they can simply reinstall:

```bash
# The new installer will replace the old files
curl -fsSL https://raw.githubusercontent.com/geraint360/pdf-deflyt/main/scripts/install-pdf-deflyt.sh | bash
```

### DEVONthink Users

DEVONthink users will need to:

1. Reinstall the DEVONthink scripts (they'll be renamed to "PDF Deflyt")
2. Update any Smart Rules that reference the old scripts
3. Restart DEVONthink to pick up the new scripts

### Communication

If this project has users, consider:

1. **GitHub Release Notes**: Announce the rename
2. **README Notice**: Add a note about the rename at the top temporarily
3. **Migration Guide**: Link to this document or provide migration instructions

## Verification Checklist

After completing the rename:

- [ ] GitHub repository renamed successfully
- [ ] Local git remote updated
- [ ] All commits pushed to new repository URL
- [ ] Installer script works from new URL
- [ ] README badges/links point to new repository
- [ ] Documentation URLs updated
- [ ] GitHub redirects from old URL working
- [ ] Issue/PR links still working (GitHub handles this automatically)

## Rollback Plan

If you need to revert the rename:

1. Rename repository back to `pdf-squeeze` on GitHub
2. Revert all local file changes using git:
   ```bash
   git log --oneline  # Find the commit before the rename
   git reset --hard <commit-hash>
   ```
3. Update git remote back to old URL
4. Force push: `git push -f origin main`

**Warning**: Only do this if absolutely necessary and no one else is using the repository.

## Related Projects

Don't forget to update references in related projects:

- ✅ **Deflyt Mac App** (`~/Developer/Deflyt/`) - already updated
- **ios-pdf-squeeze** (`~/Developer/ios-pdf-squeeze/`) - may need updates if it references the GitHub URL

## Timeline

- **Local Changes**: Completed
- **GitHub Rename**: Ready to execute
- **Test Suite Updates**: Still pending
- **Public Announcement**: After push to GitHub

---

## Questions or Issues?

If you encounter any problems during the rename:

1. Check that all local changes are committed
2. Ensure you have push access to the GitHub repository
3. Verify no one else is actively working on the repository
4. Consider coordinating with any collaborators before renaming

---

**Last Updated**: 2025-10-11
**Status**: Ready for GitHub rename

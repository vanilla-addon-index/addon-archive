# Scripts

This folder contains utility scripts for the ConsoleExperienceClassic addon.

## create-release.ps1

Creates a release zip file of the addon, excluding development files and folders.

### Usage

```powershell
# Run from the scripts folder
.\create-release.ps1

# Or specify a custom output path
.\create-release.ps1 -OutputPath "C:\Path\To\Output.zip"
```

### What's Excluded

The script automatically excludes:
- `scripts\` folder (this folder)
- `resources\` folder
- `.github\` folder (GitHub Actions)
- `.git\` folder
- `docs\` folder
- `.gitignore` file
- `version.txt` file
- `release-please-*.json` files
- `*.md` files (README, CHANGELOG, etc.)
- PowerShell scripts in the root directory

### Output

The zip file will be created in the parent directory (`Interface\AddOns\`) with the name:
`ConsoleExperienceClassic-v{version}.zip`

The version is automatically read from `version.txt` or the `.toc` file.

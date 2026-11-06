#!/usr/bin/env python3
"""
package_release.py - BigWigs WoW 1.12 Release Packager

Creates a clean distribution ZIP archive for World of Warcraft 1.12 / Turtle-WoW.
Adheres to WoW addon packaging standards:
- Internal root folder is 'BigWigs/' containing 'BigWigs.toc'
- Excludes development, testing, git, and IDE configuration files.
"""

import argparse
import os
import sys
import zipfile
from pathlib import Path

EXCLUDED_DIRS = {
    ".git",
    ".github",
    ".vscode",
    "tools",
    "scratch",
    "__pycache__",
    ".pytest_cache",
    ".agents",
}

EXCLUDED_FILES = {
    ".gitignore",
    ".luarc.json",
    "Makefile",
}

EXCLUDED_EXTENSIONS = {
    ".py",
    ".pyc",
    ".pyo",
    ".pyd",
    ".zip",
    ".tar",
    ".gz",
    ".bak",
    ".tmp",
    ".pdf",
}


def should_include_file(rel_path: Path) -> bool:
    parts = rel_path.parts
    # Check if any parent directory is excluded
    for part in parts[:-1]:
        if part in EXCLUDED_DIRS or part.startswith("."):
            return False

    filename = parts[-1]
    if filename in EXCLUDED_FILES or filename.startswith("."):
        return False

    return rel_path.suffix.lower() not in EXCLUDED_EXTENSIONS


def package_addon(repo_root: Path, output_path: Path) -> int:
    toc_path = repo_root / "BigWigs.toc"
    if not toc_path.exists():
        print(f"Error: BigWigs.toc not found in {repo_root}", file=sys.stderr)
        return 1

    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    included_count = 0
    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(repo_root):
            # Prune excluded directories
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS and not d.startswith(".")]

            for file in sorted(files):
                abs_path = Path(root) / file
                rel_path = abs_path.relative_to(repo_root)

                if should_include_file(rel_path):
                    # Internal archive path must be prefixed with 'BigWigs/'
                    archive_path = Path("BigWigs") / rel_path
                    zf.write(abs_path, str(archive_path).replace("\\", "/"))
                    included_count += 1

    size_kb = output_path.stat().st_size / 1024
    print(f"Successfully packaged {included_count} files into:")
    print(f"  Path: {output_path.resolve()}")
    print(f"  Size: {size_kb:.1f} KB ({size_kb / 1024:.2f} MB)")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Package BigWigs WoW addon for release")
    parser.add_argument(
        "--version",
        type=str,
        default="2.0.0",
        help="Release version string (e.g. 2.0.0 or v2.0.0)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="dist",
        help="Directory to save the packaged ZIP archive (defaults to 'dist')",
    )
    parser.add_argument(
        "--output-name",
        type=str,
        default=None,
        help="Custom filename for the ZIP archive",
    )

    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parent.parent

    version_clean = args.version.lstrip("v")
    filename = args.output_name or f"BigWigs-v{version_clean}.zip"
    out_dir = Path(args.output_dir)
    if not out_dir.is_absolute():
        out_dir = repo_root / out_dir
    output_path = out_dir / filename

    sys.exit(package_addon(repo_root, output_path))


if __name__ == "__main__":
    main()

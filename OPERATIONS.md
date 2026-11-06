# Using this archive

This repository mirrors the source snapshots and latest published releases for every addon listed in the Vanilla Addon Index. Upstream Git history is not imported. Each entry has a folder; alternate links for the same entry are preserved in component subfolders. Original READMEs, source files and license notices are kept under each component's `source/`. Upstream `.gitattributes` and `.gitignore` files receive an added `.upstream` suffix so their filters cannot affect this archive. Release assets keep their upstream filenames under `releases/<tag>--<release-id>/assets/`, alongside release notes and a source archive for that tag.

The MIT license in this repository applies only to its automation. Mirrored files retain their upstream licenses and attribution. To report a concern, use the [content concern issue form](https://github.com/vanilla-addon-index/addon-archive/issues/new/choose). Please identify the affected project and archive path; no legal wording or proof is required. Issues are public, so do not include private contact details. Reports are reviewed promptly.

The newest stable release is selected by publication date; projects with only prereleases use their newest prerelease. All assets of that release are retained. Older release folders are replaced after a successful update; earlier committed versions remain recoverable from Git and LFS history. Failed updates preserve the last good copy.

## Automatic updates

- **Discover addons:** nightly at 01:23 UTC. Reads the published `addons.json` snapshot and mirrors up to 250 components per run. New entries and source links are queued automatically; each run resumes at the next batch. The initial catalogue contains 1,038 addon entries.
- **Refresh mirrors:** Sundays at 02:41 UTC. Checks up to 200 components per run and resumes at the next batch. Each mirror keeps the current upstream source and latest release. Source archives and assets without trusted SHA-256 digests are downloaded again to detect replacements.
- Both workflows have a **Run workflow** button. A shared writer lock prevents concurrent commits. Failed components retain their last successful copy and are retried in later discovery runs. GitHub schedules are best effort.

## Configuration and limits

`config.json` selects the published catalogue, addon entry type, listing route, batch sizes, release scope and storage limits. Registry data lives under `.github/state/`: `registry.json` maps stable site IDs and source URLs to archive folders, `objects.json` records unique content hashes and cumulative logical bytes, and `cursor.json` resumes batch processing. Each component has a `mirror.json` provenance record and `SHA256SUMS` file.

The importer starts with a 16 GiB cumulative content allowance and 2 GiB per-file limit. These are importer guards, not GitHub account billing limits. Git LFS also counts historical objects and has separate bandwidth limits. Check the organization allowance before increasing these values. Oversized or unsupported sources remain visible with an error status; the automation does not silently claim that they were mirrored.

Source code and release files are downloaded without running upstream build scripts or workflows. GitHub API calls use the Actions token, while upstream Git downloads remain anonymous. Submodule transports are restricted, and symlinks are stored as inert link-text files with their targets recorded in `mirror.json`.

## Local use and backup

Install Node.js 22, Git and Git LFS. Authenticate `gh` before running discovery or refresh. Use `npm run initialize` to prepare the registry and README, `npm run discover` or `npm run update` to process a batch, and `npm run verify` to validate checksums. A full local verification requires hydrated LFS files.

To copy the complete archive to a Git LFS-capable server:

```sh
git clone --mirror https://github.com/vanilla-addon-index/addon-archive.git
cd addon-archive.git
git lfs fetch --all
git remote add local YOUR_LOCAL_GIT_URL
git push --mirror local
git lfs push --all local
```

Use a dedicated empty destination for `--mirror`, since it copies refs and can remove destination refs. For a filesystem backup, clone normally, run `git lfs pull`, and copy the hydrated working directory.

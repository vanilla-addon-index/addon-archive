"""Build and verify an installable release using only the standard library."""
import argparse
from pathlib import Path, PurePosixPath
import re
import struct
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'DoesItDie'
DOCS = ('README.md', 'LICENSE', 'CHANGELOG.md')


def verify(path, expected):
    with ZipFile(path) as archive:
        assert archive.testzip() is None, 'ZIP checksum failure'
        names = archive.namelist()
        assert set(names) == set(expected), 'Unexpected or missing archive entries'
        assert len(names) == len(set(names)), 'Duplicate entries'
        for name in names:
            part = PurePosixPath(name)
            assert not part.is_absolute() and '..' not in part.parts
            assert part.parts[0] == 'DoesItDie' and len(part.parts) > 1
            assert archive.read(name) == expected[name], f'Content mismatch: {name}'
        toc = archive.read('DoesItDie/DoesItDie.toc').decode('utf-8-sig')
        for line in toc.splitlines():
            line = line.strip()
            if line and not line.startswith('#'):
                assert 'DoesItDie/' + line.replace('\\', '/') in names, line
        skull = archive.read('DoesItDie/Textures/Skull.tga')
        assert skull[2] == 2, 'Texture must be an uncompressed true-color TGA'
        assert struct.unpack_from('<HH', skull, 12) == (64, 64)
        assert skull[16] == 32, 'Texture must retain its alpha channel'
        assert 'Joe Greive' in archive.read('DoesItDie/LICENSE').decode()
    print(f'PASS: {len(names)} entries, one DoesItDie/ folder, TOC, texture, license, checksums')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='Destination ZIP (default: dist/)')
    args = parser.parse_args()
    toc = (ADDON / 'DoesItDie.toc').read_text(encoding='utf-8-sig')
    version = re.search(r'^## Version:\s*(.+)$', toc, re.M).group(1).strip()
    tag = version.replace('-vanilla-alpha', '-alpha')
    path = args.output or ROOT / 'dist' / f'DoesItDie-v{tag}.zip'
    expected = {}
    for source in ADDON.rglob('*'):
        if source.is_file():
            assert source.suffix.lower() in ('.lua', '.toc', '.tga'), f'Unexpected addon file: {source}'
            expected['DoesItDie/' + source.relative_to(ADDON).as_posix()] = source.read_bytes()
    for doc in DOCS:
        expected['DoesItDie/' + doc] = (ROOT / doc).read_bytes()
    path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(path, 'w', ZIP_DEFLATED) as archive:
        for name, content in sorted(expected.items()):
            archive.writestr(name, content)
    verify(path, expected)
    print(path)


if __name__ == '__main__':
    main()

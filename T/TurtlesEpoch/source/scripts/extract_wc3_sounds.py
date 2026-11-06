#!/usr/bin/env python3
"""
Extract sound files from Warcraft III Reforged CASC storage.

Uses CascLib (https://github.com/ladislav-zezula/CascLib) via ctypes.
Build CascLib first:
    cd /tmp && git clone --depth 1 https://github.com/ladislav-zezula/CascLib.git
    cd CascLib && mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ..
    make -j$(nproc)

Usage:
    # List all sound files
    python scripts/extract_wc3_sounds.py --wc3-path "/path/to/Warcraft III" --list

    # Extract all sound files to output directory
    python scripts/extract_wc3_sounds.py --wc3-path "/path/to/Warcraft III" --output extracted_sounds

    # Extract only campaign dialogue
    python scripts/extract_wc3_sounds.py --wc3-path "/path/to/Warcraft III" --output extracted_sounds --filter campaign

    # Extract only unit sounds
    python scripts/extract_wc3_sounds.py --wc3-path "/path/to/Warcraft III" --output extracted_sounds --filter units

    # Extract both campaign + units
    python scripts/extract_wc3_sounds.py --wc3-path "/path/to/Warcraft III" --output extracted_sounds --filter campaign,units
"""

import argparse
import ctypes
import ctypes.util
import os
import sys
from pathlib import Path

# ── CascLib ctypes bindings ──────────────────────────────────────────────────

MAX_PATH = 1024  # Linux value (Windows is 260, CascLib uses 1024 on non-Windows)
MD5_HASH_SIZE = 16

# CascLib enum for name types
CASC_NAME_FULL = 0
CASC_NAME_DATA_ID = 1
CASC_NAME_CKEY = 2
CASC_NAME_EKEY = 3


class CASC_FIND_DATA(ctypes.Structure):
    _fields_ = [
        ("szFileName", ctypes.c_char * MAX_PATH),
        ("CKey", ctypes.c_ubyte * MD5_HASH_SIZE),
        ("EKey", ctypes.c_ubyte * MD5_HASH_SIZE),
        ("TagBitMask", ctypes.c_uint64),
        ("FileSize", ctypes.c_uint64),
        ("szPlainName", ctypes.c_char_p),
        ("dwFileDataId", ctypes.c_uint32),
        ("dwLocaleFlags", ctypes.c_uint32),
        ("dwContentFlags", ctypes.c_uint32),
        ("dwSpanCount", ctypes.c_uint32),
        # bFileAvailable is a bitfield (1 bit) followed by NameType enum (4 bytes)
        # Pack them as uint32 + uint32 since bitfields are tricky in ctypes
        ("_bFileAvailable_and_flags", ctypes.c_uint32),
        ("NameType", ctypes.c_int),
    ]

    @property
    def bFileAvailable(self):
        return self._bFileAvailable_and_flags & 1


def load_casclib(lib_path=None):
    """Load CascLib shared library."""
    search_paths = []
    if lib_path:
        search_paths.append(lib_path)

    # Common build locations
    search_paths.extend([
        "/tmp/CascLib/build/libcasc.so",
        "/usr/local/lib/libcasc.so",
        "/usr/lib/libcasc.so",
    ])

    # Try system library path
    system_lib = ctypes.util.find_library("casc")
    if system_lib:
        search_paths.append(system_lib)

    for path in search_paths:
        if os.path.exists(path):
            try:
                lib = ctypes.CDLL(path)
                print(f"Loaded CascLib from: {path}")
                return lib
            except OSError as e:
                print(f"  Failed to load {path}: {e}")
                continue

    print("ERROR: CascLib not found. Build it first:")
    print("  cd /tmp && git clone --depth 1 https://github.com/ladislav-zezula/CascLib.git")
    print("  cd CascLib && mkdir build && cd build")
    print("  cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ..")
    print("  make -j$(nproc)")
    sys.exit(1)


def setup_functions(lib):
    """Set up ctypes function signatures for CascLib."""
    # CascOpenStorage(path, locale, &handle) -> bool
    lib.CascOpenStorage.argtypes = [ctypes.c_char_p, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)]
    lib.CascOpenStorage.restype = ctypes.c_bool

    # CascCloseStorage(handle) -> bool
    lib.CascCloseStorage.argtypes = [ctypes.c_void_p]
    lib.CascCloseStorage.restype = ctypes.c_bool

    # CascFindFirstFile(handle, mask, &findData, listFile) -> HANDLE
    lib.CascFindFirstFile.argtypes = [ctypes.c_void_p, ctypes.c_char_p,
                                       ctypes.POINTER(CASC_FIND_DATA), ctypes.c_char_p]
    lib.CascFindFirstFile.restype = ctypes.c_void_p

    # CascFindNextFile(findHandle, &findData) -> bool
    lib.CascFindNextFile.argtypes = [ctypes.c_void_p, ctypes.POINTER(CASC_FIND_DATA)]
    lib.CascFindNextFile.restype = ctypes.c_bool

    # CascFindClose(findHandle) -> bool
    lib.CascFindClose.argtypes = [ctypes.c_void_p]
    lib.CascFindClose.restype = ctypes.c_bool

    # CascOpenFile(handle, fileName, locale, flags, &fileHandle) -> bool
    lib.CascOpenFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32,
                                  ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)]
    lib.CascOpenFile.restype = ctypes.c_bool

    # CascGetFileSize(handle, &sizeHigh) -> DWORD
    lib.CascGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
    lib.CascGetFileSize.restype = ctypes.c_uint32

    # CascReadFile(handle, buffer, toRead, &read) -> bool
    lib.CascReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32,
                                  ctypes.POINTER(ctypes.c_uint32)]
    lib.CascReadFile.restype = ctypes.c_bool

    # CascCloseFile(handle) -> bool
    lib.CascCloseFile.argtypes = [ctypes.c_void_p]
    lib.CascCloseFile.restype = ctypes.c_bool

    # GetCascError() -> DWORD
    lib.GetCascError.argtypes = []
    lib.GetCascError.restype = ctypes.c_uint32

    return lib


# ── CASC operations ─────────────────────────────────────────────────────────

INVALID_HANDLE = ctypes.c_void_p(-1).value  # 0xFFFFFFFF...
CASC_LOCALE_ALL = 0xFFFFFFFF
CASC_OPEN_BY_NAME = 0x00000000


def open_storage(lib, wc3_path):
    """Open a CASC storage at the given path."""
    handle = ctypes.c_void_p()
    path_bytes = str(wc3_path).encode("utf-8")
    if not lib.CascOpenStorage(path_bytes, CASC_LOCALE_ALL, ctypes.byref(handle)):
        err = lib.GetCascError()
        print(f"ERROR: Failed to open CASC storage at '{wc3_path}' (error {err})")
        sys.exit(1)
    return handle


def list_files(lib, storage, mask=b"*"):
    """List all files matching the mask in the CASC storage."""
    find_data = CASC_FIND_DATA()
    files = []

    find_handle = lib.CascFindFirstFile(storage, mask, ctypes.byref(find_data), None)
    if find_handle is None or find_handle == INVALID_HANDLE:
        return files

    while True:
        filename = find_data.szFileName.decode("utf-8", errors="replace")
        files.append({
            "name": filename,
            "size": find_data.FileSize,
            "available": find_data.bFileAvailable,
            "name_type": find_data.NameType,
        })
        if not lib.CascFindNextFile(find_handle, ctypes.byref(find_data)):
            break

    lib.CascFindClose(find_handle)
    return files


def extract_file(lib, storage, filename, output_path):
    """Extract a single file from CASC storage to disk."""
    file_handle = ctypes.c_void_p()
    filename_bytes = filename.encode("utf-8") if isinstance(filename, str) else filename

    if not lib.CascOpenFile(storage, filename_bytes, CASC_LOCALE_ALL,
                            CASC_OPEN_BY_NAME, ctypes.byref(file_handle)):
        return False

    # Get file size
    size_high = ctypes.c_uint32()
    size_low = lib.CascGetFileSize(file_handle, ctypes.byref(size_high))
    if size_low == 0xFFFFFFFF:
        lib.CascCloseFile(file_handle)
        return False

    file_size = size_low + (size_high.value << 32)
    if file_size == 0:
        lib.CascCloseFile(file_handle)
        return False

    # Read the file in chunks
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    CHUNK_SIZE = 65536
    bytes_remaining = file_size
    with open(output_path, "wb") as f:
        while bytes_remaining > 0:
            to_read = min(CHUNK_SIZE, bytes_remaining)
            buf = ctypes.create_string_buffer(to_read)
            bytes_read = ctypes.c_uint32()
            if not lib.CascReadFile(file_handle, buf, to_read, ctypes.byref(bytes_read)):
                break
            if bytes_read.value == 0:
                break
            f.write(buf.raw[:bytes_read.value])
            bytes_remaining -= bytes_read.value

    lib.CascCloseFile(file_handle)
    return True


# ── Sound file filtering ────────────────────────────────────────────────────

# WC3 sound file paths we care about
SOUND_EXTENSIONS = {".wav", ".ogg", ".mp3", ".flac"}

# Filter categories
FILTER_PATTERNS = {
    "campaign": [
        "sound/dialogue/",
        "sound/campaign/",
        "sound\\dialogue\\",
        "sound\\campaign\\",
    ],
    "units": [
        "sound/units/",
        "sound\\units\\",
        ":units/",
        ":units\\",
    ],
    "ambient": [
        "sound/ambient/",
        "sound\\ambient\\",
    ],
    "music": [
        "sound/music/",
        "sound\\music\\",
    ],
}


def is_sound_file(filename):
    """Check if a filename is a sound file."""
    ext = os.path.splitext(filename.lower())[1]
    return ext in SOUND_EXTENSIONS


def matches_filter(filename, filters):
    """Check if a filename matches any of the given filter categories."""
    if not filters:
        return True  # No filter = match everything
    fn_lower = filename.lower().replace("\\", "/")
    for category in filters:
        patterns = FILTER_PATTERNS.get(category, [])
        for pattern in patterns:
            if pattern.replace("\\", "/") in fn_lower:
                return True
    return False


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Extract sound files from Warcraft III Reforged CASC storage"
    )
    parser.add_argument("--wc3-path", required=True,
                        help="Path to Warcraft III installation directory")
    parser.add_argument("--output", "-o", default=None,
                        help="Output directory for extracted files")
    parser.add_argument("--list", action="store_true",
                        help="List matching sound files without extracting")
    parser.add_argument("--filter", default=None,
                        help="Comma-separated categories: campaign,units,ambient,music (default: all sounds)")
    parser.add_argument("--casclib", default=None,
                        help="Path to libcasc.so (default: auto-detect)")
    parser.add_argument("--all-files", action="store_true",
                        help="List ALL files in CASC, not just sounds")
    args = parser.parse_args()

    if not args.list and not args.output:
        parser.error("Either --list or --output is required")

    # Parse filter categories
    filters = None
    if args.filter:
        filters = [f.strip().lower() for f in args.filter.split(",")]
        invalid = [f for f in filters if f not in FILTER_PATTERNS]
        if invalid:
            parser.error(f"Unknown filter categories: {', '.join(invalid)}. "
                         f"Valid: {', '.join(FILTER_PATTERNS.keys())}")

    # Load CascLib
    lib = setup_functions(load_casclib(args.casclib))

    # Open storage
    wc3_path = Path(args.wc3_path).resolve()
    if not wc3_path.exists():
        print(f"ERROR: WC3 path does not exist: {wc3_path}")
        sys.exit(1)

    print(f"Opening CASC storage: {wc3_path}")
    storage = open_storage(lib, wc3_path)
    print("Storage opened successfully.")

    # List all files
    print("Scanning files...")
    all_files = list_files(lib, storage)
    print(f"Total files in CASC: {len(all_files)}")

    if args.all_files:
        for f in sorted(all_files, key=lambda x: x["name"]):
            avail = "+" if f["available"] else "-"
            print(f"  [{avail}] {f['size']:>10} {f['name']}")
        lib.CascCloseStorage(storage)
        return

    # Filter to sound files
    sound_files = [f for f in all_files
                   if is_sound_file(f["name"]) and matches_filter(f["name"], filters)]

    print(f"Sound files matching filter: {len(sound_files)}")

    if args.list:
        # Group by top-level directory for overview
        dirs = {}
        for f in sound_files:
            parts = f["name"].replace("\\", "/").split("/")
            key = "/".join(parts[:3]) if len(parts) >= 3 else f["name"]
            dirs.setdefault(key, []).append(f)

        for d in sorted(dirs.keys()):
            files_in_dir = dirs[d]
            total_size = sum(f["size"] for f in files_in_dir)
            size_mb = total_size / (1024 * 1024)
            print(f"  {d}: {len(files_in_dir)} files ({size_mb:.1f} MB)")

        print(f"\nTotal: {len(sound_files)} files, "
              f"{sum(f['size'] for f in sound_files) / (1024*1024):.1f} MB")
    else:
        # Extract files
        output_dir = Path(args.output)
        print(f"Extracting to: {output_dir}")

        extracted = 0
        failed = 0
        for i, f in enumerate(sound_files):
            # Normalize path separators and remove colons (CASC uses : as module separator)
            rel_path = f["name"].replace("\\", "/").replace(":", "/")
            out_path = output_dir / rel_path

            if extract_file(lib, storage, f["name"], out_path):
                extracted += 1
            else:
                failed += 1
                print(f"  FAILED: {f['name']}")

            if (i + 1) % 100 == 0:
                print(f"  Progress: {i+1}/{len(sound_files)} ({extracted} ok, {failed} failed)")

        print(f"\nDone: {extracted} extracted, {failed} failed out of {len(sound_files)}")

    lib.CascCloseStorage(storage)


if __name__ == "__main__":
    main()

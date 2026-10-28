#!/usr/bin/env python3
"""Report image identity and optionally enforce the exact Git master blob.

A ChatGPT 'PNG' attachment can contain JPEG bytes or be rescaled. Pixel
geometry and visual similarity are not proof of source identity. This check
uses Git's SHA-1 blob-object framing, not the SHA-256 of the file alone.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

GIT_MASTER_BLOB = "1fbf3fe02f99fcb4fb03168045ea12d237c09e59"
SOURCE_SIZE = (1198, 1313)


def inspect_file(path, expected_blob=GIT_MASTER_BLOB):
    path = Path(path)
    data = path.read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(data)).encode("ascii")
                        + b"\0" + data).hexdigest()
    with Image.open(path) as im:
        fmt = im.format
        size = im.size
        rgb_hash = hashlib.sha256(im.convert("RGB").tobytes()).hexdigest()
    is_png = data.startswith(bytes((137, 80, 78, 71, 13, 10, 26, 10)))
    return {
        "filename": path.name,
        "detected_format": fmt,
        "extension": path.suffix.lower(),
        "size_bytes": len(data),
        "dimensions": list(size),
        "file_sha256": hashlib.sha256(data).hexdigest(),
        "rgb_sha256": rgb_hash,
        "git_blob_sha1": blob,
        "expected_git_blob_sha1": expected_blob,
        "png_signature": is_png,
        "geometry_matches_p1": size == SOURCE_SIZE,
        "exact_git_source_match": (
            is_png and fmt == "PNG" and size == SOURCE_SIZE
            and blob == expected_blob
        ),
        "usage": "git_master" if (
            is_png and fmt == "PNG" and size == SOURCE_SIZE
            and blob == expected_blob
        ) else "visual_reference_only",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--require-exact-git-source", action="store_true")
    args = parser.parse_args()
    info = inspect_file(args.source)
    encoded = json.dumps(info, indent=2, ensure_ascii=False)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    if args.require_exact_git_source and not info["exact_git_source_match"]:
        parser.exit(2, "REJECTED: file is not the unmodified Git master PNG.\n")


if __name__ == "__main__":
    main()

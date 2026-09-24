#!/usr/bin/env python3
"""Download and verify a Hugging Face artifact manifest.

The manifest must be a resolved Mumla `ModelArtifact` JSON file with byte counts
and SHA-256 checksums. Downloads are resumable through `.part` files and are
verified before being moved into place.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="Resolved model artifact JSON")
    parser.add_argument("output_dir", type=Path, help="Directory to download into")
    parser.add_argument("--dry-run", action="store_true", help="Print planned downloads without writing files")
    args = parser.parse_args()

    artifact = json.loads(args.manifest.read_text())
    repo_id = artifact["id"]
    revision = artifact.get("revision")
    if not revision:
        sys.exit("Manifest must include a pinned revision.")

    total_bytes = sum(int(item.get("byteCount", 0)) for item in artifact["files"])
    print(f"{repo_id}@{revision}")
    print(f"{len(artifact['files'])} files, {format_bytes(total_bytes)}")

    for item in artifact["files"]:
        path = item["path"]
        expected_size = int(item["byteCount"])
        expected_sha256 = item.get("sha256")
        if not expected_sha256:
            sys.exit(f"{path}: manifest is missing sha256")

        destination = args.output_dir / path
        print(f"- {path} ({format_bytes(expected_size)})")
        if args.dry_run:
            continue

        download_file(repo_id, revision, path, destination, expected_size)
        actual_sha256 = sha256(destination)
        if actual_sha256.lower() != expected_sha256.lower():
            destination.unlink(missing_ok=True)
            sys.exit(f"{path}: checksum mismatch, removed downloaded file")

    if not args.dry_run:
        print("OK: downloaded and verified")

    return 0


def download_file(repo_id: str, revision: str, path: str, destination: Path, expected_size: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and destination.stat().st_size == expected_size:
        return

    partial = destination.with_suffix(destination.suffix + ".part")
    existing_size = partial.stat().st_size if partial.exists() else 0
    if existing_size > expected_size:
        partial.unlink()
        existing_size = 0

    url = hf_resolve_url(repo_id, revision, path)
    request = urllib.request.Request(url)
    if existing_size:
        request.add_header("Range", f"bytes={existing_size}-")

    try:
        with urllib.request.urlopen(request) as response, partial.open("ab") as handle:
            if existing_size and response.status != 206:
                handle.seek(0)
                handle.truncate()
                existing_size = 0
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                handle.write(chunk)
    except urllib.error.HTTPError as error:
        if error.code == 416 and partial.exists() and partial.stat().st_size == expected_size:
            pass
        else:
            raise

    actual_size = partial.stat().st_size
    if actual_size != expected_size:
        sys.exit(f"{path}: expected {expected_size} bytes, got {actual_size}")

    os.replace(partial, destination)


def hf_resolve_url(repo_id: str, revision: str, path: str) -> str:
    quoted_repo = urllib.parse.quote(repo_id, safe="/")
    quoted_revision = urllib.parse.quote(revision, safe="")
    quoted_path = urllib.parse.quote(path, safe="/")
    return f"https://huggingface.co/{quoted_repo}/resolve/{quoted_revision}/{quoted_path}"


def sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def format_bytes(value: int) -> str:
    amount = float(value)
    for unit in ["B", "KB", "MB", "GB"]:
        if amount < 1024 or unit == "GB":
            return f"{amount:.1f} {unit}"
        amount /= 1024
    raise AssertionError("unreachable")


if __name__ == "__main__":
    raise SystemExit(main())


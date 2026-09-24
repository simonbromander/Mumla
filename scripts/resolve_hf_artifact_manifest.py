#!/usr/bin/env python3
"""Resolve Hugging Face artifact metadata for a Mumla model manifest.

The input manifest names the Hugging Face repo, revision and files Mumla expects.
This script fills byte counts and SHA-256 checksums from Hugging Face metadata.
Large LFS files expose SHA-256 directly in the API; small non-LFS files are
downloaded and hashed when they are below the configured size limit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_SMALL_FILE_LIMIT = 5 * 1024 * 1024


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("template", type=Path, help="Input model artifact template JSON")
    parser.add_argument("output", type=Path, help="Output resolved artifact JSON")
    parser.add_argument(
        "--small-file-limit",
        type=int,
        default=DEFAULT_SMALL_FILE_LIMIT,
        help="Maximum non-LFS file size to download for SHA-256 hashing",
    )
    args = parser.parse_args()

    artifact = json.loads(args.template.read_text())
    repo_id = artifact["id"]
    revision = artifact.get("revision")
    if not revision:
        sys.exit("Manifest must include a pinned revision before resolving metadata.")

    api = hugging_face_model_api(repo_id, revision)
    if api.get("sha") != revision:
        sys.exit(f"Revision mismatch: manifest has {revision}, API returned {api.get('sha')}")

    siblings = {item["rfilename"]: item for item in api.get("siblings", [])}
    resolved_files = []
    missing = []

    for file_entry in artifact["files"]:
        path = file_entry["path"]
        sibling = siblings.get(path)
        if sibling is None:
            missing.append(path)
            continue

        resolved = dict(file_entry)
        lfs = sibling.get("lfs")
        if lfs:
            resolved["byteCount"] = int(lfs["size"])
            resolved["sha256"] = lfs["sha256"]
        else:
            size = int(sibling["size"])
            resolved["byteCount"] = size
            if size <= args.small_file_limit:
                resolved["sha256"] = sha256_for_hf_file(repo_id, revision, path)
            elif "sha256" not in resolved:
                print(
                    f"warning: {path} is non-LFS and too large to hash without download",
                    file=sys.stderr,
                )

        resolved_files.append(resolved)

    if missing:
        for path in missing:
            print(f"missing from Hugging Face metadata: {path}", file=sys.stderr)
        return 1

    artifact["files"] = resolved_files
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(f"Wrote {args.output}")
    return 0


def hugging_face_model_api(repo_id: str, revision: str) -> dict[str, Any]:
    quoted_repo = urllib.parse.quote(repo_id, safe="/")
    quoted_revision = urllib.parse.quote(revision, safe="")
    url = f"https://huggingface.co/api/models/{quoted_repo}/revision/{quoted_revision}?blobs=true"
    return read_json(url)


def sha256_for_hf_file(repo_id: str, revision: str, path: str) -> str:
    quoted_repo = urllib.parse.quote(repo_id, safe="/")
    quoted_revision = urllib.parse.quote(revision, safe="")
    quoted_path = urllib.parse.quote(path, safe="/")
    url = f"https://huggingface.co/{quoted_repo}/resolve/{quoted_revision}/{quoted_path}"

    hasher = hashlib.sha256()
    with urllib.request.urlopen(url) as response:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def read_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url) as response:
        return json.load(response)


if __name__ == "__main__":
    raise SystemExit(main())


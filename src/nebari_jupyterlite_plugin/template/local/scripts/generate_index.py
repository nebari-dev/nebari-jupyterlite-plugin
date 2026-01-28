#!/usr/bin/env python3
"""Generate JupyterLite contents index (all.json) from a directory."""

import json
import mimetypes
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path


def get_mimetype(path):
    mime, _ = mimetypes.guess_type(str(path))
    return mime


def get_file_type(path):
    if path.is_dir():
        return "directory"
    if path.suffix == ".ipynb":
        return "notebook"
    return "file"


def generate_entry(path, relative_path):
    stat = path.stat()
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    return {
        "content": None,
        "created": now,
        "format": None,
        "hash": None,
        "hash_algorithm": None,
        "last_modified": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat().replace("+00:00", "Z"),
        "mimetype": get_mimetype(path) if path.is_file() else None,
        "name": path.name,
        "path": relative_path,
        "size": stat.st_size if path.is_file() else None,
        "type": get_file_type(path),
        "writable": True,
    }


def scan_directory(source_dir, prefix=""):
    entries = []
    for item in sorted(source_dir.iterdir()):
        if item.name.startswith("."):
            continue
        relative_path = f"{prefix}{item.name}" if prefix else item.name
        entries.append(generate_entry(item, relative_path))
        if item.is_dir():
            entries.extend(scan_directory(item, f"{relative_path}/"))
    return entries


def generate_index(source_dir):
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    return {
        "content": scan_directory(source_dir),
        "created": now,
        "format": "json",
        "hash": None,
        "hash_algorithm": None,
        "last_modified": now,
        "mimetype": None,
        "name": "",
        "path": "",
        "size": None,
        "type": "directory",
        "writable": True,
    }


def copy_files(source_dir, output_dir):
    files_dir = output_dir / "files"
    files_dir.mkdir(parents=True, exist_ok=True)
    for item in source_dir.iterdir():
        if item.name.startswith("."):
            continue
        dest = files_dir / item.name
        if item.is_dir():
            shutil.copytree(item, dest, dirs_exist_ok=True)
        else:
            shutil.copy2(item, dest)


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <source_dir> <output_dir>")
        sys.exit(1)
    source_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    if not source_dir.exists():
        print(f"Source directory does not exist: {source_dir}")
        sys.exit(1)
    api_dir = output_dir / "api" / "contents"
    api_dir.mkdir(parents=True, exist_ok=True)
    index = generate_index(source_dir)
    index_file = api_dir / "all.json"
    with open(index_file, "w") as f:
        json.dump(index, f, indent=2)
    print(f"Generated index with {len(index['content'])} entries: {index_file}")
    copy_files(source_dir, output_dir)
    print(f"Copied files to: {output_dir / 'files'}")


if __name__ == "__main__":
    main()

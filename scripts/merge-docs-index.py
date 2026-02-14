#!/usr/bin/env python3
"""Merge ListKit's doccarchive index into the combined docs/index/index.json.

xcodebuild docbuild generates separate doccarchives per module. The Lists
archive drives the SPA, but its index.json only knows about com.listkit.Lists.
This script adds com.listkit.ListKit to includedArchiveIdentifiers and merges
the ListKit navigator tree so the SPA can resolve cross-module links.
"""

import json
import sys


def main():
  if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <listkit-doccarchive> <docs-dir>")
    sys.exit(1)

  listkit_archive = sys.argv[1]
  docs_dir = sys.argv[2]

  lists_index_path = f"{docs_dir}/index/index.json"
  listkit_index_path = f"{listkit_archive}/index/index.json"

  with open(lists_index_path) as f:
    lists_index = json.load(f)

  with open(listkit_index_path) as f:
    listkit_index = json.load(f)

  # Add ListKit archive identifier
  archive_ids = lists_index.get("includedArchiveIdentifiers", [])
  listkit_ids = listkit_index.get("includedArchiveIdentifiers", [])
  for aid in listkit_ids:
    if aid not in archive_ids:
      archive_ids.append(aid)
  lists_index["includedArchiveIdentifiers"] = archive_ids

  # Merge ListKit navigator tree into Lists
  listkit_items = listkit_index.get("interfaceLanguages", {}).get("swift", [])
  lists_items = lists_index.get("interfaceLanguages", {}).get("swift", [])

  if lists_items and listkit_items:
    # Append ListKit's top-level modules as children of the root
    root = lists_items[0]
    children = root.get("children", [])
    children.extend(listkit_items)
    root["children"] = children

  with open(lists_index_path, "w") as f:
    json.dump(lists_index, f, separators=(",", ":"))

  print(f"Merged {len(listkit_items)} ListKit entries into {lists_index_path}")
  print(f"Archive identifiers: {archive_ids}")


if __name__ == "__main__":
  main()

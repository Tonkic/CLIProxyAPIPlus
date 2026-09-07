#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <os> <arch> <archive-dir>" >&2
  exit 2
fi

target_os="$1"
target_arch="$2"
archive_dir="$3"
manager_version="${MANAGER_VERSION:?MANAGER_VERSION is required}"

case "$target_os" in
  windows)
    extension="zip"
    manager_name="cpa-manager-plus.exe"
    ;;
  darwin|linux)
    extension="tar.gz"
    manager_name="cpa-manager-plus"
    ;;
  *)
    echo "CPA-Manager-Plus does not publish binaries for $target_os" >&2
    exit 2
    ;;
esac

asset="cpa-manager-plus_${manager_version}_${target_os}_${target_arch}.${extension}"
base_url="https://github.com/seakee/CPA-Manager-Plus/releases/download/${manager_version}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

curl -fL --retry 5 --retry-delay 2 --retry-connrefused \
  "${base_url}/${asset}" -o "${work_dir}/${asset}"
curl -fL --retry 5 --retry-delay 2 --retry-connrefused \
  "${base_url}/checksums.txt" -o "${work_dir}/checksums.txt"

python - "${work_dir}/${asset}" "${work_dir}/checksums.txt" <<'PY'
import hashlib
import pathlib
import sys

asset = pathlib.Path(sys.argv[1])
checksums = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()
expected = None
for line in checksums:
    parts = line.strip().split()
    listed_name = pathlib.PurePosixPath(parts[-1].lstrip("*")).name if len(parts) >= 2 else ""
    if listed_name == asset.name:
        expected = parts[0].lower()
        break
if expected is None:
    raise SystemExit(f"missing checksum for {asset.name}")
actual = hashlib.sha256(asset.read_bytes()).hexdigest()
if actual != expected:
    raise SystemExit(f"checksum mismatch for {asset.name}: {actual} != {expected}")
PY

extract_dir="${work_dir}/extract"
mkdir -p "$extract_dir" "$archive_dir/manager"
if [[ "$extension" == "zip" ]]; then
  unzip -q "${work_dir}/${asset}" -d "$extract_dir"
else
  tar -xzf "${work_dir}/${asset}" -C "$extract_dir"
fi

manager_bin="$(find "$extract_dir" -type f -name "$manager_name" | head -n 1)"
test -n "$manager_bin"
cp "$manager_bin" "$archive_dir/manager/$manager_name"

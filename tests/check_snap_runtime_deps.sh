#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
snapcraft_file="$repo_root/snap/snapcraft.yaml"

version="$(awk '/^version:/ { print $2; exit }' "$snapcraft_file")"

if [[ -z "$version" ]]; then
  echo "Could not determine snap version from $snapcraft_file" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

deb_url="https://github.com/AppFlowy-IO/AppFlowy/releases/download/$version/AppFlowy-$version-linux-x86_64.deb"
deb_file="$tmpdir/AppFlowy-$version-linux-x86_64.deb"

wget -q -O "$deb_file" "$deb_url"

pushd "$tmpdir" >/dev/null
ar x "$deb_file" data.tar.xz
tar -xJf data.tar.xz ./usr/lib/AppFlowy/lib/libmpv.so.2
popd >/dev/null

if ! objdump -p "$tmpdir/usr/lib/AppFlowy/lib/libmpv.so.2" | grep -q 'NEEDED \+libvdpau.so.1'; then
  echo "Expected bundled libmpv.so.2 to require libvdpau.so.1 for AppFlowy $version" >&2
  exit 1
fi

if ! grep -Fxq '      - libvdpau1' "$snapcraft_file"; then
  echo "snapcraft.yaml does not stage libvdpau1 even though bundled libmpv.so.2 requires libvdpau.so.1" >&2
  exit 1
fi

if ! grep -Fxq '      - usr/lib/*/libvdpau.so.1*' "$snapcraft_file"; then
  echo "snapcraft.yaml does not prime libvdpau.so.1 into the snap runtime" >&2
  exit 1
fi

echo "Snap runtime dependency check passed for AppFlowy $version"

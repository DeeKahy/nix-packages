#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq nix
# Bumps sources.json to the latest pob-redux release, or to the version
# given as the first argument. Set FORCE=1 to refetch the current version.

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
json="$dir/sources.json"
repo="pobredux/pob-redux"

current="$(jq -r .version "$json")"

if [[ $# -gt 0 ]]; then
  latest="${1#v}"
else
  auth=()
  if [[ -n ${GITHUB_TOKEN:-} ]]; then
    auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  latest="$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)"
  latest="${latest#v}"
fi

if [[ $current == "$latest" && -z ${FORCE:-} ]]; then
  echo "pob-redux is up to date ($current)"
  exit 0
fi

# Keep in sync with the assets table in package.nix.
asset_for() {
  case "$1" in
    x86_64-linux) echo amd64.deb ;;
    aarch64-linux) echo arm64.deb ;;
    aarch64-darwin) echo aarch64.app.tar.gz ;;
  esac
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
jq --arg v "$latest" '.version = $v' "$json" >"$tmp"

for system in x86_64-linux aarch64-linux aarch64-darwin; do
  url="https://github.com/$repo/releases/download/v$latest/PoB.Redux_${latest}_$(asset_for "$system")"
  echo "fetching $url"
  hash="$(nix --extra-experimental-features nix-command store prefetch-file --json "$url" | jq -r .hash)"
  jq --arg s "$system" --arg h "$hash" '.hashes[$s] = $h' "$tmp" >"$tmp.next"
  mv "$tmp.next" "$tmp"
done

cp "$tmp" "$json"
echo "pob-redux: $current -> $latest"

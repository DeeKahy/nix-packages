#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq nix
# Bumps sources.json to the latest awakened-poe-trade release, or to the
# version given as the first argument. Set FORCE=1 to refetch the current version.

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
json="$dir/sources.json"
repo="SnosMe/awakened-poe-trade"

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
  echo "awakened-poe-trade is up to date ($current)"
  exit 0
fi

# Keep in sync with the src urls in package.nix.
asset_for() {
  case "$1" in
    linux) echo "Awakened-PoE-Trade-$latest.AppImage" ;;
    darwin) echo "Awakened-PoE-Trade-$latest-universal.dmg" ;;
  esac
}

tmp="$(mktemp)"
trap 'rm -f "$tmp" "$tmp.next"' EXIT
jq --arg v "$latest" '.version = $v' "$json" >"$tmp"

for os in linux darwin; do
  url="https://github.com/$repo/releases/download/v$latest/$(asset_for "$os")"
  echo "fetching $url"
  hash="$(nix --extra-experimental-features nix-command store prefetch-file --json "$url" | jq -r .hash)"
  jq --arg s "$os" --arg h "$hash" '.hashes[$s] = $h' "$tmp" >"$tmp.next"
  mv "$tmp.next" "$tmp"
done

cp "$tmp" "$json"
echo "awakened-poe-trade: $current -> $latest"

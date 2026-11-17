# nix-packages

Packages I use that are not in nixpkgs yet. The layout copies nixpkgs
(`pkgs/by-name/<first two letters>/<name>/package.nix`), so a package
directory can be copied into a nixpkgs checkout as is when it is ready
for a PR.

## Packages

| Package | Platforms | Notes |
|---|---|---|
| `pob-redux` | x86_64-linux, aarch64-linux, aarch64-darwin | Repackages the upstream release binaries (`.deb` on Linux, the `.app` on macOS) |
| `awakened-poe-trade` | x86_64-linux, aarch64-linux, aarch64-darwin | Universal `.dmg` on macOS; on Linux it runs the AppImage's `app.asar` with nixpkgs' electron |

## Using it

Build or run one directly:

```sh
nix run github:DeeKahy/nix-packages#pob-redux
```

Or add it as a flake input and use the overlay:

```nix
inputs.nix-packages = {
  url = "github:DeeKahy/nix-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};

# then
nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
environment.systemPackages = [ pkgs.pob-redux ];
```

## Updating

```sh
nix run .#update
```

That runs every `update.sh` under `pkgs/by-name`. Each one checks the
latest upstream release and rewrites its `sources.json` with the new
version and hashes. One package can also be bumped on its own, optionally
to a specific version:

```sh
./pkgs/by-name/po/pob-redux/update.sh 0.5.12
```

Set `GITHUB_TOKEN` if the GitHub API starts rate limiting you.

## pob-redux notes

- The in-app updater cannot replace files in the nix store. Ignore its
  banner and update through this repo instead.
- Upstream only builds macOS for Apple Silicon, so there is no
  x86_64-darwin.
- Before upstreaming: add yourself to `maintainers/maintainer-list.nix`
  in nixpkgs and to `meta.maintainers`, and expect reviewers to ask
  whether a source build is possible (the repo builds with Tauri, bun and
  cargo, so it is, but it needs a bun dependency fetcher).

## awakened-poe-trade notes

- nixpkgs already has this package, but for Linux only. The point of
  having it here is macOS. Upstreaming would mean adding the darwin
  branch to the nixpkgs package rather than adding a new one.
- Using the overlay replaces the nixpkgs version on Linux too, which
  only matters if nixpkgs is newer.
- Upstream does not sign the macOS app. If Gatekeeper blocks it, open it
  once from Finder with right-click > Open.
- Its hotkeys copy items out of the game, so macOS will ask for
  Accessibility permission (System Settings > Privacy & Security).

# nix-packages

Packages I use that are not in nixpkgs yet. The layout copies nixpkgs
(`pkgs/by-name/<first two letters>/<name>/package.nix`), so a package
directory can be copied into a nixpkgs checkout as is when it is ready
for a PR.

## Packages

| Package | Platforms | Notes |
|---|---|---|
| `pob-redux` | x86_64-linux, aarch64-linux, aarch64-darwin | Repackages the upstream release binaries (`.deb` on Linux, the `.app` on macOS) |

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

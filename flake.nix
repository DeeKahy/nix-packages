{
  description = "Personal nix packages, laid out like nixpkgs so they can be upstreamed";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # pkgs/by-name/<shard>/<name>/package.nix, same as nixpkgs.
      byName = ./pkgs/by-name;
      packageFiles = lib.concatMapAttrs (
        shard: _:
        lib.mapAttrs (name: _: byName + "/${shard}/${name}/package.nix") (
          builtins.readDir (byName + "/${shard}")
        )
      ) (builtins.readDir byName);

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      overlays.default = final: _prev: lib.mapAttrs (_: file: final.callPackage file { }) packageFiles;

      packages = forAllSystems (
        pkgs:
        lib.filterAttrs (_: pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg) (
          lib.mapAttrs (_: file: pkgs.callPackage file { }) packageFiles
        )
      );

      # nix run .#update runs every package's update script.
      apps = forAllSystems (pkgs: {
        update = {
          type = "app";
          program = lib.getExe (
            pkgs.writeShellApplication {
              name = "update";
              runtimeInputs = with pkgs; [
                bash
                curl
                jq
                nix
              ];
              text = ''
                cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
                for script in pkgs/by-name/*/*/update.sh; do
                  bash "$script"
                done
              '';
            }
          );
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}

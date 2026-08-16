{
  description = "NixOS packaging and service module for WiFi Audio Streaming";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wfas-src = {
      url = "github:marcomorosi06/WiFiAudioStreaming-Desktop/master";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      wfas-src,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
            };
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, ... }:
        let
          wfas = pkgs.callPackage ./package.nix {
            src = wfas-src;
          };
        in
        {
          inherit wfas;
          default = wfas;
        }
      );

      overlays.default = final: prev: {
        wfas = final.callPackage ./package.nix {
          src = wfas-src;
        };
      };

      nixosModules.default =
        { pkgs, lib, ... }:
        {
          imports = [
            ./modules/wfas.nix
          ];
          # Unless explicitly overridden by services.wfas.package, use
          # the package built from this flake's pinned WFAS source.
          services.wfas.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };

      apps = forAllSystems (
        { system, ... }:
        {
          update-deps = {
            type = "app";
            program = "${self.packages.${system}.wfas.mitmCache.updateScript}";
          };
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}

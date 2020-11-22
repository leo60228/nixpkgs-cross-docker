{
  inputs.nixpkgs.url = "nixpkgs/8a3b33baed9458a0af56a710b535bedf6d6c2598";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      crossSystems = with nixpkgs.lib.systems.examples; [
        {
          nix = "x86_64-linux";
          nixpkgs = gnu64;
        }
        {
          nix = "aarch64-linux";
          nixpkgs = aarch64-multiplatform;
        }
      ];
      hostSystems = flake-utils.lib.defaultSystems;
      fromNative = [ "busybox" ];
      makeImage = host: cross:
        let
          hostPkgs = import nixpkgs {
            system = host;
          };
          nativePkgs = import nixpkgs {
            system = cross.nix;
          };
          crossPkgs = import nixpkgs {
            system = host;
            crossSystem = cross.nixpkgs;
            overlays = [
              (self: super: nixpkgs.lib.getAttrs fromNative nativePkgs)
              (self: super: {
                dockerTools = hostPkgs.dockerTools.override {
                  system = cross.nix;
                };
              })
            ];
          };
          pkgs = if cross.nix == host then hostPkgs else crossPkgs;
          inherit (pkgs) dockerTools busybox;
          image = dockerTools.buildLayeredImage {
            name = "nix-busybox";
            contents = [ nativePkgs.busybox ];
            config = {
              Cmd = [ "${nativePkgs.busybox}/bin/sh" ];
            };
          };
        in image;
      imagePairsForHost = host: builtins.map (cross: {
        name = cross.nix;
        value = makeImage host cross;
      }) crossSystems;
      imagesForHost = host: builtins.listToAttrs (imagePairsForHost host);
      images = nixpkgs.lib.genAttrs hostSystems imagesForHost;
      outputs = {
        packages = images;
      };
    in outputs;
}

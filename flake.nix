{
  description = "Build Zephyr projects on Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix.url = "github:nix-community/pyproject.nix";

    zephyr.url = "github:zephyrproject-rtos/zephyr/v3.5.0";
    zephyr.flake = false;
  };

  outputs = { self, nixpkgs, zephyr, pyproject-nix }: (
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in
    {
      checks = self.packages;

      packages =
        forAllSystems
          (
            system:
            let
              pkgs = nixpkgs.legacyPackages.${system};
            in
            builtins.removeAttrs
              (pkgs.callPackage ./. {
                zephyr-src = zephyr;
                inherit pyproject-nix;
              }) [ "override" "overrideDerivation" ]
          );
    }
  );
}

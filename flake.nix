{
  description = "Build Zephyr projects on Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    pyproject-nix.url = "github:nix-community/pyproject.nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";

    zephyr.url = "github:zephyrproject-rtos/zephyr/v3.7.0";
    zephyr.flake = false;
  };

  outputs = { self, nixpkgs, zephyr, pyproject-nix }: (
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      clean = lib.flip removeAttrs [
        "override"
        "overrideDerivation"
        "callPackage"
        "overrideScope"
        "overrideScope'"
        "newScope"
        "packages"
      ];
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
              clean (pkgs.callPackage ./. {
                zephyr-src = zephyr;
                inherit pyproject-nix;
              })
          );
    }
  );
}

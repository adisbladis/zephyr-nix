{
  description = "Build Zephyr projects on Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix.url = "github:nix-community/pyproject.nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-python.url = "github:cachix/nixpkgs-python";
    nixpkgs-python.inputs.nixpkgs.follows = "nixpkgs";

    zephyr.url = "github:zephyrproject-rtos/zephyr/v3.7.0";
    zephyr.flake = false;
  };

  outputs = { self, nixpkgs, zephyr, pyproject-nix, nixpkgs-python }: (
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

              callPackage = lib.callPackageWith (pkgs // {
                python38 = nixpkgs-python.packages.${system}."3.8";
              });

            in
              clean (callPackage ./. {
                zephyr-src = zephyr;
                inherit pyproject-nix;
              })
          );
    }
  );
}

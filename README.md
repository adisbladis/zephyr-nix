# zephyr-nix

Develop Zephyr projects using Nix

## Features

* SDK packaging
  * `sdk`

  The minimal SDK.
  Can be overriden with additional targets.

  ``` nix
  sdk.override {
    targets = [
      "arm-zephyr-eabi"
    ];
  }
  ```

  * `sdkFull`

  SDK with all targets enabled.

* Host tools packaging

  * `hosttools`

  Binary `hosttools` from the Zephyr SDK.
  Because of libc incompatibilities not all binaries in this derivation actually works.

  * `hosttools-nix`

  A re-packaging of the Zephyr SDK hosttools using nixpkgs packages.

## Basic usage

- `shell.nix`

``` nix
{ mkShell
, zephyr
, callPackage
, cmake
, ninja
, lib
}:

mkShell {
  packages = [
    (zephyr.sdk.override {
      targets = [
        "arm-zephyr-eabi"
      ];
    })
    zephyr.pythonEnv
    # Use zephyr.hosttools-nix to use nixpkgs built tooling instead of official Zephyr binaries
    zephyr.hosttools
    cmake
    ninja
  ];

}
```

## Flakes usage

- `flake.nix`
``` nix
{
  description = "A very basic Zephyr flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Customize the version of Zephyr used by the flake here
    zephyr.url = "github:zephyrproject-rtos/zephyr/v3.5.0";
    zephyr.flake = false;

    zephyr-nix.url = "github:nix-community/zephyr-nix";
    zephyr-nix.inputs.nixpkgs.follows = "nixpkgs";
    zephyr-nix.inputs.zephyr.follows = "zephyr";
  };

  outputs = { self, nixpkgs, zephyr-nix, ... }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    zephyr = zephyr-nix.packages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      # Use the same mkShell as documented above
    };
  };
}
```

## Overriding Python packages

To change a single Python package, use the `packageOverrides` argument of `pythonEnv`. This works
on the `packages` output, so you do not need your own `nixpkgs`:

``` nix
zephyr-nix.packages.x86_64-linux.pythonEnv.override {
  packageOverrides = final: prev: {
    spsdk = prev.spsdk.overridePythonAttrs (old: {
      postPatch = "";
    });
  };
}
```

These overrides are applied last, so they take precedence over the overrides that `zephyr-nix`
applies itself.

A `pythonPackagesExtensions` overlay cannot win, because Nixpkgs applies it before the
`packageOverrides` of the interpreter. Use the argument above for the packages that `zephyr-nix`
patches.

## Using your own nixpkgs

The `packages` output is built from the `nixpkgs` input of `zephyr-nix`, so it does not see your
overlays. Use the overlay or `lib.mkZephyr` to build `zephyr-nix` against your own package set.
Both apply your own overrides of `python3` before the ones of `zephyr-nix`, so your overrides win.

### Overlay

Add `overlays.default` to your package set and use `pkgs.zephyr-nix`:

``` nix
  outputs = { self, nixpkgs, zephyr-nix, ... }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [
        zephyr-nix.overlays.default
        # Your own overlays are applied here
      ];
    };

    zephyr = pkgs.zephyr-nix;
  in {
    # Use the same devShell as documented above
  };
```

This is also the way to use `zephyr-nix` from a NixOS or a home-manager configuration:

``` nix
nixpkgs.overlays = [ zephyr-nix.overlays.default ];
```

### lib.mkZephyr

Call `lib.mkZephyr` with a package set that you build yourself:

``` nix
    zephyr = zephyr-nix.lib.mkZephyr { inherit pkgs; };
```

`mkZephyr` also takes an optional `zephyr-src`, which defaults to the `zephyr` input of
`zephyr-nix`. Point it at your own Zephyr checkout to read `scripts/requirements.txt` from there.

### The result

Both ways return the classic Nix attribute set. The SDK versions stay nested in `sdks`, and the set
keeps `override` and `overrideScope`, so you can replace an input of `zephyr-nix` itself:

``` nix
zephyr.overrideScope (final: prev: {
  openocd-zephyr = prev.openocd-zephyr.overrideAttrs (old: { ... });
})
```

## Using specific SDK versions

`zephyr-nix` packages multiple Zephyr SDK versions that can be accessed by their versioned attributes.

- Classic Nix
```
{ pkgs, zephyr-nix }:
pkgs.mkShell {
  packages = [
    zephyr-nix.sdks."0_16".sdkFull
  ];
}
```

- Flakes

Flake output schema requires packages to be flat, so the nested SDKs sets are folded into the top-level:

```
devShells.x86_64-linux.default = pkgs.mkShell {
  packages = [
    zephyr-nix.packages.x86_64-linux.sdkFull-0_16
  ];
};
```

## Building a west project with Nix

For building [west](https://docs.zephyrproject.org/latest/develop/west/index.html) projects with Nix you can use [west2nix](https://github.com/adisbladis/west2nix).

---

This project is developed by [adisbladis](https://blad.is/consulting/).

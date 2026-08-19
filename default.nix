let
  # The defaults below make this file work without flakes. They read the pins
  # from flake.lock, so both entry points use the same revisions.
  lock = import ./lock.nix;
in

{ lib
, newScope
, openocd
, gcc_multi
, autoreconfHook
, fetchFromGitHub
, zephyr-src ? lock.zephyr
, pyproject-nix ? import lock.pyproject-nix { inherit lib; }
, uv-python-src ? lock.uv-python
  # Nixpkgs dropped python310. `callPackage` fills this argument in when the
  # package set still has it, otherwise build a pre-packaged binary.
, python310 ? (newScope { } (import uv-python-src { }) { })."cpython-3.10"
, python312 ? null
}:

lib.makeScope newScope (self: let
  inherit (self) callPackage;

  mkSdk = version: args: callPackage (import ./sdk.nix (lib.importJSON ./sdks/${version}.json)) args;

  sdks = lib.fix (self: {
    "1_0" = mkSdk "1_0_1" {
      python3 = python312;
    };
    "1_0_0" = lib.warn "zephyr-nix: SDK 1.0.0 is deprecated, please use the '1_0' alias which always points to the latest 1.0.x release" self."1_0";
    "0_17" = mkSdk "0_17" {
      python3 = python310;
    };
    "0_16" = mkSdk "0_16" {
      python3 = python310;
    };
    latest = self."1_0";
  });

in {
  inherit (sdks.latest) sdk sdkFull hosttools;
  inherit sdks;

  # Zephyr/west Python environment.
  pythonEnv = callPackage ./python.nix {
    inherit zephyr-src;
    inherit pyproject-nix;
  };

  openocd-zephyr = openocd.overrideAttrs(old: let
    pname = "openocd-zephyr";
    version = "20220611";
  in {
    inherit pname version;
    name = "${pname}-${version}";

    nativeBuildInputs = old.nativeBuildInputs ++ [
      autoreconfHook
    ];

    src = fetchFromGitHub {
      owner = "zephyrproject-rtos";
      repo = "openocd";
      rev = "b6f95a16c1360e347a06faf91befd122c0d15864";
      hash = "sha256-NItD5vrFlm3vfma5DexRYpGDsrl7yLjgmskiXPpbYP8=";
    };
  });

  # A variant of hosttools, but all tools are taken from nixpkgs.
  hosttools-nix = callPackage
    ({ stdenv
     , bossa
     , dtc
     , nettle
     , openocd-zephyr
     , qemu
     , shared-mime-info
     }: stdenv.mkDerivation {
      name = "zephyr-sdk-hosttools-nix";

      dontUnpack = true;
      dontBuild = true;

      propagatedBuildInputs = [
        bossa
        dtc
        nettle
        openocd-zephyr
        qemu
        shared-mime-info
      ]
      ++ lib.optional (stdenv.hostPlatform.system == "x86_64-linux") gcc_multi
      ;

      installPhase = ''
        mkdir $out
      '';
    })
    { };
})

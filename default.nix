{ pyproject-nix
, lib
, newScope
, openocd
, gcc_multi
, autoreconfHook
, fetchFromGitHub
, python310
}:

lib.makeScope newScope (self: let
  inherit (self) callPackage;

  mkSdk = version: args: callPackage (import ./sdk.nix (lib.importJSON ./sdks/${version}.json)) args;

  sdks = lib.fix (self: {
    "0_17" = mkSdk "0_17" {
      python3 = python310;
    };

    "0_16" = mkSdk "0_16" {
      python3 = python310;
    };

    latest = self."0_17";
  });

in {
  inherit (sdks.latest) sdk sdkFull hosttools;
  inherit sdks;

  # Zephyr/west Python environment.
  pythonEnv = callPackage ./python.nix {
    zephyr-src = fetchFromGitHub {
      owner = "zephyrproject-rtos";
      repo = "zephyr";
      rev = "v3.7.0";
      hash = "sha256-rmOHH0uRU27U2T4w4+FEMcAcuiZ7W7p4vOwtSwiAFNY=";
    };
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
     , qemu_full
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
        qemu_full
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

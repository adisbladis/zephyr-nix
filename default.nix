{ zephyr-src
, pyproject-nix
, lib
, newScope
, openocd
, gcc_multi
, autoreconfHook
, fetchFromGitHub
, pkgs
}:

lib.makeScope newScope (self: let
  inherit (self) callPackage;

  sdk = callPackage (import ./sdk.nix (lib.importJSON ./sdk.json)) {
    python3 = pkgs.python310;
  };

in {
  inherit (sdk) sdk sdkFull hosttools;

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

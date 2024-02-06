{ callPackage
, zephyr-src
, pyproject-nix
, lib
, fetchurl
, python38
}:

let
  sdk' = lib.importJSON ./sdk.json;
  inherit (sdk') version;

  getPlatform = stdenv:
    if stdenv.isLinux then "linux"
    else if stdenv.isDarwin then "macos"
    else throw "Unsupported platform";

  getArch = stdenv:
    if stdenv.isLinux then stdenv.hostPlatform.linuxArch
    else if stdenv.isDarwin then stdenv.hostPlatform.darwinArch
    else throw "Unsupported arch";

  baseURL = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}";

  fetchSDKFile = file: fetchurl {
    url = "${baseURL}/${file}";
    sha256 = sdk'.files.${file};
  };

  sdkArgs = {
    python3 = python38;
  };

in
rec {
  # Zephyr/west Python environment.
  pythonEnv = callPackage ./python.nix {
    inherit zephyr-src;
    inherit pyproject-nix;
  };

  # Pre-package Zephyr SDK.
  sdk = callPackage
    ({ stdenv
     , which
     , cmake
     , autoPatchelfHook
     , python3
     , targets ? [ ]
     }:
      let
        platform = getPlatform stdenv;
        arch = getArch stdenv;
      in
      stdenv.mkDerivation {
        pname = "zephyr-sdk";
        inherit version;

        srcs = [
          (fetchSDKFile "zephyr-sdk-${version}_${platform}-${arch}_minimal.tar.xz")
        ] ++ map fetchSDKFile (map (target: "toolchain_${platform}-${arch}_${target}.tar.xz") targets);

        passthru = {
          inherit platform arch targets;
        };

        nativeBuildInputs = [ which cmake autoPatchelfHook ];

        buildInputs = [ stdenv.cc.cc python3 ];

        dontBuild = true;
        dontUseCmakeConfigure = true;

        sourceRoot = ".";

        installPhase = ''
          runHook preInstall

          rm zephyr-sdk-$version/zephyr-sdk-${arch}-hosttools-standalone-*.sh
          rm zephyr-sdk-$version/setup.sh;

          mv zephyr-sdk-$version $out
          mv $(ls | grep -v env-vars) $out/

          runHook postInstall
        '';
      })
    sdkArgs;

  # # SDK with all targets selected
  sdkFull =
    let
      inherit (sdk.passthru) platform arch;
      mToolchain = builtins.match "toolchain_${platform}-${arch}_(.+)\.tar\.xz";
      allTargets = map (x: builtins.head (mToolchain x)) (builtins.filter (f: mToolchain f != null) (lib.attrNames sdk'.files));
    in
    sdk.override {
      targets = allTargets;
    };

  # Binary host tools provided by the Zephyr project.
  hosttools = callPackage
    ({ stdenv
     , which
     , autoPatchelfHook
     , python3
     }:
      let
        platform = getPlatform stdenv;
        arch = getArch stdenv;
      in
      stdenv.mkDerivation {
        pname = "zephyr-sdk-hosttools";
        inherit version;

        src = fetchSDKFile "hosttools_${platform}-${arch}.tar.xz";

        nativeBuildInputs = [ which autoPatchelfHook ];

        buildInputs = [ python3 ];

        dontBuild = true;

        sourceRoot = ".";

        installPhase = ''
          runHook preInstall
          mkdir -p $out/usr/share/zephyr/hosttools
          ./zephyr-sdk-${arch}-hosttools-standalone-*.sh -d $out/usr/share/zephyr/hosttools
          ln -s $out/usr/share/zephyr/hosttools/sysroots/${arch}-pokysdk-${platform}/usr/bin $out/bin
          runHook postInstall
        '';
      })
    sdkArgs;

  # A variant of hosttools, but all tools are taken from nixpkgs.
  hosttools-nix = callPackage
    ({ stdenv
     , bossa
     , dtc
     , nettle
     , openocd
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
        openocd
        qemu_full
        shared-mime-info
      ];

      installPhase = ''
        mkdir $out
      '';
    })
    { };
}

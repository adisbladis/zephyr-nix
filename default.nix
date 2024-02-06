{ callPackage
, stdenv
, zephyr-src
, pyproject-nix
, lib
, fetchurl
, which
, autoPatchelfHook
, cmake
, python38
, pkgs
}:

let
  sdk = lib.importJSON ./sdk.json;
  inherit (sdk) version;

  python3 = python38;

  platform =
    if stdenv.isLinux then "linux"
    else if stdenv.isDarwin then "macos"
    else throw "Unsupported platform";

  arch =
    if stdenv.isLinux then stdenv.hostPlatform.linuxArch
    else if stdenv.isDarwin then stdenv.hostPlatform.darwinArch
    else throw "Unsupported arch";

  baseURL = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}";

  fetchSDKFile = file: fetchurl {
    url = "${baseURL}/${file}";
    sha256 = sdk.files.${file};
  };

in
{
  # Zephyr/west Python environment.
  pythonEnv = callPackage ./python.nix {
    inherit zephyr-src;
    inherit pyproject-nix;
  };

  # Pre-package Zephyr SDK.
  sdk = stdenv.mkDerivation (finalAttrs: {
    pname = "zephyr-sdk";
    inherit version;

    srcs = [
      (fetchSDKFile "zephyr-sdk-${version}_${platform}-${arch}_minimal.tar.xz")
    ] ++ map fetchSDKFile (map (target: "toolchain_${platform}-${arch}_${target}.tar.xz") finalAttrs.targets);

    targets = [ ];  # Zephyr targets

    nativeBuildInputs = [ which cmake autoPatchelfHook ];

    buildInputs = [ stdenv.cc.cc python38 ];

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
  });

  # Binary host tools provided by the Zephyr project.
  hosttools = stdenv.mkDerivation {
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
  };

  # A variant of hosttools, but all tools are taken from nixpkgs.
  hosttools-nix = stdenv.mkDerivation {
    name = "zephyr-sdk-hosttools-nix";

    dontUnpack = true;
    dontBuild = true;

    propagatedBuildInputs = with pkgs; [
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
  };
}

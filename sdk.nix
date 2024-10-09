sdk':
let
  inherit (sdk') version;

  baseURL = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}";

  getPlatform =
    stdenv:
    if stdenv.isLinux then
      "linux"
    else if stdenv.isDarwin then
      "macos"
    else
      throw "Unsupported platform";

  getArch =
    stdenv:
    if stdenv.isAarch64 then
      "aarch64"
    else if stdenv.isx86_64 then
      "x86_64"
    else
      throw "Unsupported arch";

  fetchSDKFile' =
    fetchurl: file:
    fetchurl {
      url = "${baseURL}/${file}";
      sha256 = sdk'.files.${file};
    };

in
  {
    lib,
    python3,
    newScope,
    ncurses,
    libxcrypt-legacy,
  }:
lib.makeScope newScope (self: let
  inherit (self) callPackage;
in {

  # Pre-packaged Zephyr SDK.
  sdk =
    callPackage ({
      stdenv,
      which,
      cmake,
      autoPatchelfHook,
      python3,
      fetchurl,
      lib,
      targets ? [ ],
    }:
    let
      platform = getPlatform stdenv;
      arch = getArch stdenv;

      fetchSDKFile = fetchSDKFile' fetchurl;

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

      nativeBuildInputs = [
        which
        cmake
      ] ++ lib.optional (!stdenv.isDarwin) autoPatchelfHook;

      buildInputs = [
        stdenv.cc.cc
        python3
        ncurses
        libxcrypt-legacy
      ];

      dontBuild = true;
      dontUseCmakeConfigure = true;

      sourceRoot = ".";

      installPhase = ''
        runHook preInstall

        rm -f zephyr-sdk-$version/zephyr-sdk-${arch}-hosttools-standalone-*.sh
        rm -f env-vars

        mv zephyr-sdk-$version $out

        if [ -n "$(ls -A .)" ]; then
          mv * $out
        fi

        mkdir -p $out/nix-support
        cat <<EOF >> $out/nix-support/setup-hook
        export ZEPHYR_SDK_INSTALL_DIR=$out
        EOF

        runHook postInstall
      '';
    }) {
      inherit python3;
    };

  # SDK with all targets selected
  sdkFull =
    let
      inherit (self.sdk.passthru) platform arch;
      mToolchain = builtins.match "toolchain_${platform}-${arch}_(.+)\.tar\.xz";
      allTargets = map (x: builtins.head (mToolchain x)) (builtins.filter (f: mToolchain f != null) (lib.attrNames sdk'.files));
    in
    self.sdk.override {
      targets = allTargets;
    };

  # Binary host tools provided by the Zephyr project.
  hosttools =
    callPackage ({
      stdenv,
      which,
      autoPatchelfHook,
      python3,
      lib,
      fetchurl,
    }:
    let
      platform = getPlatform stdenv;
      arch = getArch stdenv;
      fetchSDKFile = fetchSDKFile' fetchurl;
    in
    stdenv.mkDerivation {
      pname = "zephyr-sdk-hosttools";
      inherit version;

      src = fetchSDKFile "hosttools_${platform}-${arch}.tar.xz";

      nativeBuildInputs = [ which ] ++ lib.optional (!stdenv.isDarwin) autoPatchelfHook;

      buildInputs = [ python3 ];

      dontBuild = true;
      dontFixup = true;

      sourceRoot = ".";

      installPhase = ''
        runHook preInstall
        mkdir -p $out/usr/share/zephyr/hosttools
        ./zephyr-sdk-${arch}-hosttools-standalone-*.sh -d $out/usr/share/zephyr/hosttools
        ln -s $out/usr/share/zephyr/hosttools/sysroots/${arch}-pokysdk-${platform}/usr/bin $out/bin
        runHook postInstall
      '';
    }) {
      inherit python3;
    };
})

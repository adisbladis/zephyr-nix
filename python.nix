{ python3
, zephyr-src
, pyproject-nix
, clang-tools_17
, gitlint
, lib
, extraPackages ? _ps: [ ]
, pkgs
}:

let
  python = python3.override {
    self = python;
    packageOverrides = self: super: {
      # HACK: Zephyr uses pypi to install non-Python deps
      clang-format = clang-tools_17;
      inherit gitlint;

      # Nixpkgs has incorrect canonical naming
      python-can = super.python-can or self.can;

      # Upstream bug. Network tests for canopen-2.3.0 may fail due to fragile timing assumptions
      canopen = super.canopen.overridePythonAttrs (old: {
        doCheck = false;
      });

      # Nixpkgs puts imgtool in the top-level set as mcuboot-imgtool since 2024-10
      imgtool =
        if pkgs ? mcuboot-imgtool then pkgs.mcuboot-imgtool.override {
          python3Packages = self;
        } else super.imgtool;

      # Upstream bug. Bz is not a valid pypi package.
      bz = null;

      # Nixpkgs has moved gcovr to the top-level namespace
      gcovr =
        if super ? gcovr then super.gcovr
        else pkgs.gcovr.override {
          python3Packages = self;
        };

      # HACK: Older Zephyr depends on these missing dependencies
      sphinxcontrib-svg2pdfconverter = super.sphinxcontrib-svg2pdfconverter or null;

      # see: https://github.com/NixOS/nixpkgs/issues/375763
      anytree = super.anytree.overrideAttrs (old: {
        patches = old.patches ++ [ ./python-anytree-poetry-project-name-version.patch ];
      });

      sphinx-lint = self.buildPythonPackage rec {
        pname = "sphinx-lint";
        version = "1.0.0";
        format = "wheel";

        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/31/d2/a130ffba531af7cbbb0e7ad24c7d577d3de0b797437f61d3a7234ed6d836/sphinx_lint-1.0.0-py3-none-any.whl";
          hash = "sha256-YReg80Cy3HPq38V9t1MdRHfgkp+SoMGi9h5u28Jy8Lw=";
        };

        propagatedBuildInputs = with self; [
          polib
          regex
        ];

        meta = with lib; {
          description = "Check for stylistic and formal issues in .rst and .py files included in the documentation.";
          homepage = "https://github.com/sphinx-contrib/sphinx-lint";
          # license = licenses.python;
          maintainers = with maintainers; [ ];
        };
      };
    };
  };

  project = pyproject-nix.lib.project.loadRequirementsTxt {
    requirements = zephyr-src + "/scripts/requirements.txt";
  };

  invalidConstraints = project.validators.validateVersionConstraints { inherit python; };

in
lib.warnIf
  (invalidConstraints != { })
  "zephyr-pythonEnv: Found invalid Python constraints for: ${builtins.toJSON (lib.attrNames invalidConstraints)}"
  (python.withPackages (project.renderers.withPackages {
    inherit python;
    extraPackages = ps: [ ps.west ] ++ extraPackages ps;
  }))

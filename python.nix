{ python3
, zephyr-src
, pyproject-nix
, clang-tools
, gitlint
, lib
, extraPackages ? _ps: [ ]
  # Python package overrides from the caller.
  # These are applied last, so they take precedence over every other layer.
, packageOverrides ? _self: _super: { }
, pkgs
}:

let
  zephyrPackageOverrides = self: super: {
    inherit gitlint;
    # HACK: Zephyr uses pypi to install non-Python deps
    clang-format = clang-tools;

    gitlint-core = gitlint;

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

    # Prefer existing sphinx-lint, otherwise fall back to manual packaging.
    sphinx-lint = super.sphinx-lint or (self.buildPythonPackage {
      pname = "sphinx-lint";
      version = "1.0.0";
      format = "wheel";

      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/31/d2/a130ffba531af7cbbb0e7ad24c7d577d3de0b797437f61d3a7234ed6d836/sphinx_lint-1.0.0-py3-none-any.whl";
        hash = "sha256-YReg80Cy3HPq38V9t1MdRHfgkp+SoMGi9h5u28Jy8Lw=";
      };

      propagatedBuildInputs = [
        self.polib
        self.regex
      ];
    });

    pytest-notebook = super.pytest-notebook.overridePythonAttrs (old: {
      doCheck = false;
    });

    spsdk = super.spsdk.overridePythonAttrs (old: {
      dontCheckRuntimeDeps = true;
      doCheck = false;
      preBuild = (old.preBuild or "") + ''
        export HOME=$(mktemp -d)
      '';
      # Upstream pins the build backend to versions that Nixpkgs does not
      # have. Remove the version constraints from the build requirements.
      #
      # This replaces the Nixpkgs postPatch on purpose. Nixpkgs patches the
      # same constraints with literal strings, and those strings change with
      # each spsdk release.
      postPatch = ''
        sed -i -E 's/"(setuptools([_-]scm)?)[^"]*"/"\1"/g' pyproject.toml
      '';
    });

    # Prefer existing vermin, otherwise fall back to manual packaging.
    vermin = super.vermin or (self.buildPythonPackage {
      pname = "vermin";
      version = "1.6.0";
      format = "wheel";

      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/2e/98/1a2ca43e6d646421eea16ec19977e2e6d1ea9079bd9d873bfae513d43f1c/vermin-1.6.0-py2.py3-none-any.whl";
        hash = "sha256-8fqe5A9ZmD3EDgR36ysfqAYaPfTDsrzzSa3UYqVhDvs=";
      };
    });
  };

  python = python3.override (old: {
    self = python;
    # The caller wins. The overrides of the incoming python3 come from a
    # nixpkgs overlay, so they take precedence over the overrides below.
    packageOverrides = lib.composeManyExtensions [
      zephyrPackageOverrides
      (old.packageOverrides or (_self: _super: { }))
      packageOverrides
    ];
  });

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

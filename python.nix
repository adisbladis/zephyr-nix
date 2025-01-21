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

      # HACK: Older Zephyr depends on these missing dependencies
      sphinxcontrib-svg2pdfconverter = super.sphinxcontrib-svg2pdfconverter or null;
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

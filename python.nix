{ python3
, zephyr-src
, pyproject-nix
, clang-tools_17
, gitlint
, lib
, extraLibs ? [ ]
}:

let
  python = python3.override {
    self = python;
    packageOverrides = self: super: {
      # HACK: Zephyr uses pypi to install non-Python deps
      clang-format = clang-tools_17;
      inherit gitlint;

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
    extraPackages = ps: [ ps.west ] ++ extraLibs;
  }))

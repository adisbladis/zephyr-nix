{ python3
, zephyr-src
, pyproject-nix
, clang-tools
, gitlint
}:

let
  python = python3.override {
    self = python;
    packageOverrides = self: super: {
      clang-format = clang-tools;
      inherit gitlint;
    };
  };

  project = pyproject-nix.lib.project.loadRequirementsTxt {
    requirements = zephyr-src + "/scripts/requirements.txt";
  };

in
assert project.validators.validateVersionConstraints { inherit python; } == { };
python.withPackages (project.renderers.withPackages {
  inherit python;
  extraPackages = ps: [ ps.west ];
})

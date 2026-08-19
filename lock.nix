# Fetch the flake inputs without flakes.
#
# The pins come from flake.lock, so the classic Nix entry point and the flake
# always use the same revisions. `nix flake update` updates both.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
in
builtins.mapAttrs (
  name: node:
  let
    src = node.locked;
  in
  if src.type != "github" then
    throw "zephyr-nix: lock.nix fetches GitHub inputs only, but ${name} is of type ${src.type}"
  else
    builtins.fetchTarball {
      url = "https://github.com/${src.owner}/${src.repo}/archive/${src.rev}.tar.gz";
      sha256 = src.narHash;
    }
) (removeAttrs lock.nodes [ "root" ])

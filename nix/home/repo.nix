# Location of the dotfiles checkout, set by the host file.
{ lib, ... }:
{
  options.dotfiles.repoDir = lib.mkOption {
    type = lib.types.str;
    description = "Absolute path to the dotfiles checkout for out-of-store links.";
  };
}

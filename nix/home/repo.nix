# Location of the dotfiles checkout, set by the host file.
{ config, lib, ... }:
{
  imports = [ ./shell.nix ];

  options.dotfiles.repoDir = lib.mkOption {
    type = lib.types.str;
    description = "Absolute path to the dotfiles checkout for out-of-store links.";
  };

  config.dotfiles.shell.extraEnv = ''
    export DOTFILES_DIR="${config.dotfiles.repoDir}"
  '';
}

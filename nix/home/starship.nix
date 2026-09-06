# Prompt variant selection.
{ config, lib, ... }:
{
  imports = [ ./shell.nix ];

  options.dotfiles.starship.variant = lib.mkOption {
    type = lib.types.str;
    default = "personal";
    description = "Starship base config: personal uses starship.toml, any other value starship.<variant>.toml.";
  };

  config.dotfiles.shell.extraEnv = lib.mkIf (config.dotfiles.starship.variant != "personal") ''
    export STARSHIP_CONFIG="$HOME/.config/starship.${config.dotfiles.starship.variant}.toml"
  '';
}

# Consumer-facing shell option surface. The fragments are written under
# ~/.config/shell and sourced by the shared env.sh and interactive.sh.
{ config, lib, ... }:
let
  cfg = config.dotfiles.shell;
in
{
  options.dotfiles.shell = {
    extraEnv = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell environment fragment sourced after the shared env.sh.";
    };

    extraInteractive = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Interactive shell fragment sourced after the shared interactive.sh.";
    };
  };

  config.xdg.configFile = {
    "shell/extra.env.sh" = lib.mkIf (cfg.extraEnv != "") { text = cfg.extraEnv; };
    "shell/extra.interactive.sh" = lib.mkIf (cfg.extraInteractive != "") { text = cfg.extraInteractive; };
  };
}

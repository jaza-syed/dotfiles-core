# Static CLI tool configs, linked as verbatim files.
{ ... }:
{
  xdg.configFile."atuin/config.toml".source = ./atuin-config.toml;
  xdg.configFile."direnv/direnv.toml".source = ./direnv.toml;
  home.file.".procs.toml".source = ./procs.toml;
}

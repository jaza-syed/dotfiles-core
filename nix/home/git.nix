# Public git defaults; the machine repos set the identity.
{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [
      "**/.claude/settings.local.json"
      "**/.claude/.cc-writes/"
    ];
    settings = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      alias.ci = "commit";
    };
  };
}

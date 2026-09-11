# Public SSH defaults. Private hosts belong in the ignored ~/.ssh/config.local include.
{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.local" ];
    settings = {
      "*" = {
        IgnoreUnknown = "UseKeychain";
        AddKeysToAgent = "yes";
        IdentityFile = "~/.ssh/id_ed25519";
      };
      "github.com" = {
        HostName = "github.com";
        User = "git";
      };
    };
  };

  # Paired with the tmux.conf SSH_AUTH_SOCK override for agent forwarding.
  home.file.".ssh/rc".source = ./ssh-rc;
}

# path_helper in /etc/zprofile demotes the PATH set by env.sh, so restore the
# Home Manager profile and Homebrew to the front without a second brew
# shellenv eval.
path=(
  "$HOME/.nix-profile/bin"
  /nix/var/nix/profiles/default/bin
  /opt/homebrew/bin
  /opt/homebrew/sbin
  $path
)
typeset -U path

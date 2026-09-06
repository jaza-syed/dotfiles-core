# Common Homebrew set. Homebrew itself is installed by nix-homebrew during
# the darwin switch; the flake-level wiring lives in flake.nix.
{ ... }:
{
  homebrew = {
    enable = true;
    # Move to "check", then "uninstall", once the declared set is verified.
    onActivation.cleanup = "none";

    taps = [
      "FelixKratz/formulae"
      "nikitabobko/tap"
      "jesseduffield/lazydocker"
    ];

    brews = [
      # Authentication prerequisites (install.md phase 2 uses these)
      "gh"

      # Core MacOs tools
      "FelixKratz/formulae/sketchybar"
      "FelixKratz/formulae/borders"

      # Mac App Store
      "mas"

      # AI
      "gemini-cli"
      "llama.cpp"

      # Dev
      "llvm"
      "bash"
      "bash-completion@2"
      "xcodegen"
      # Bootstrap Lua runs the theme generator before Home Manager switches.
      "lua"

      # Core CLI tools
      "coreutils"
      "gnu-sed"
      "gnu-tar"
      "grep"
      "make"
      "rlwrap"
      "mise"
      "awk"
      "tree"
      "watch"
      "wget"
      "rsync"
      "stow"
      "git-lfs"
      "jj"
      "rip2"
      "difftastic"
      "urlview"
      "fzf-tab"
      "terminal-notifier"

      # Media
      "ffmpeg"
      "imagemagick"
      "mplayer"

      # Monitoring
      "btop"
      "glances"
      "procs"

      # Misc
      "websocat"
      "graphviz"
      "gnuplot"
      "pandoc"
      "tectonic"

      # DevOps / infra
      "awscli"
      "kubernetes-cli"
      "k9s"
      "kubelogin"
      "s3cmd"
      "rclone"

      # Dev
      "uv"
      "jesseduffield/lazydocker/lazydocker"
    ];

    casks = [
      # Authentication prerequisites (install.md phase 2 uses these)
      "1password"
      "1password-cli"

      # Fonts
      "font-sf-mono-nerd-font-ligaturized"
      "font-sketchybar-app-font"
      "sf-symbols"
      "font-ibm-plex-mono"
      "font-ibm-plex-sans"

      # Core MacOs tools
      "nikitabobko/tap/aerospace"

      # AI
      "claude-code@latest"
      "claude"
      "codex"

      # Terminals & dev
      "linear"
      "wezterm@nightly"
      "temurin@25" # java
      "typora"
      "visual-studio-code"
      "zed"

      # Browsers
      "firefox"
      "google-chrome"

      # Productivity
      "obsidian"
      "zoom"
      "mimestream"
      "scroll-reverser"
      "lulu"
      "flux-app"
      "dropbox"
      "raycast"
      "slack"
      "simplenote"
      "betterdisplay"
      "figma"
      "google-drive"
      "homerow"

      # Media & audio
      "vlc"
      "obs"
      "sonos"

      # Misc
      "cloudflare-warp"
      "hammerspoon"
      "discord"
      "zulip"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Free Ruler" = 1483172210;
      "Ghostery AdBlocker for Privacy" = 6504861501;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Todoist" = 585829637;
      "WhatsApp" = 310633997;
      "Xcode" = 497799835;
    };
  };
}

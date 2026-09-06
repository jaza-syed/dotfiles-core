# Common Homebrew set. Homebrew itself is installed by nix-homebrew during
# the darwin switch; the flake-level wiring lives in flake.nix.
{ ... }:
{
  homebrew = {
    enable = true;
    # The darwin switch uninstalls undeclared formulae and casks.
    onActivation.cleanup = "uninstall";

    brews = [
      # Authentication prerequisites (install.md phase 2 uses these)
      "gh"

      # Mac App Store
      "mas"

      # AI
      "llama.cpp"

      # Dev
      "bash"
      "bash-completion@2"
      "xcodegen"

      # Media
      "mplayer"
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
      "Amphetamine" = 937984704;
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

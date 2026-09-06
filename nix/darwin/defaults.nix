# macOS defaults, previously applied by the retired scripts/macos.sh.
{ config, ... }:
let
  home = config.users.users.${config.system.primaryUser}.home;
in
{
  system.defaults = {
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 1;
      # macos.sh writes 4 and then 10; 10 is the value that wins today.
      InitialKeyRepeat = 10;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      AppleShowAllExtensions = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSWindowShouldDragOnGesture = true;
    };

    finder = {
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      ShowStatusBar = true;
      ShowPathbar = true;
    };

    dock = {
      autohide = true;
      static-only = true;
    };

    # macos.sh also creates this directory; screencapture needs it to exist.
    screencapture = {
      location = "${home}/screenshots";
      disable-shadow = true;
    };

    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    menuExtraClock.ShowSeconds = true;

    CustomUserPreferences = {
      NSGlobalDomain.NSAutomaticEmojiSubstitutionEnabled = false;
      "com.apple.desktopservices".DSDontWriteNetworkStores = true;
      "com.apple.terminal".StringEncodings = [ 4 ];
      # Safari preferences live in a sandboxed container, so these writes may
      # fail from activation just as they can from macos.sh.
      "com.apple.Safari" = {
        IncludeDevelopMenu = true;
        IncludeInternalDebugMenu = true;
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
        AutoOpenSafeDownloads = false;
      };
    };
  };
}

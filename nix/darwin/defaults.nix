# macOS defaults, previously applied by the retired scripts/macos.sh.
{ config, ... }:
let
  home = config.users.users.${config.system.primaryUser}.home;
in
{
  # Only takes effect on hosts where nix-darwin manages Nix (nix.enable).
  nix.settings.experimental-features = "nix-command flakes";

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    # Lets Touch ID answer sudo inside tmux.
    reattach = true;
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.defaults = {
    controlcenter.BatteryShowPercentage = true;

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

  # Keys 60 and 61 are the Ctrl-Space and Ctrl-Option-Space input source
  # switchers. `-dict-add` merges them into the other symbolic hotkeys, where
  # CustomUserPreferences would write the whole dictionary and drop the rest.
  # Activation runs as root, so these take the same wrapper nix-darwin uses for
  # the `system.defaults` writes above. The XML form keeps `enabled` a boolean
  # and the parameters integers; macOS ignores entries stored as strings.
  system.activationScripts.postActivation.text =
    let
      asUser = ''launchctl asuser "$(id -u -- ${config.system.primaryUser})" sudo --user=${config.system.primaryUser} --'';
      disableHotkey = key: modifiers: ''
        ${asUser} defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${key} \
          '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>${modifiers}</integer></array><key>type</key><string>standard</string></dict></dict>'
      '';
    in
    ''
      ${disableHotkey "60" "262144"}
      ${disableHotkey "61" "786432"}
      ${asUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';
}

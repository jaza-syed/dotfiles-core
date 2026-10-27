{
  description = "Reusable Home Manager and nix-darwin modules plus the base bootstrap profiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    direnv-instant = {
      url = "github:Mic92/direnv-instant";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Has no nixpkgs input; its only input is Homebrew itself.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # The bash counterpart of zsh-fzf-tab, which nixpkgs does not package.
    fzf-tab-completion = {
      url = "github:lincheney/fzf-tab-completion";
      flake = false;
    };
    # nixpkgs 26.05 has 2.23.0, where a click on an empty part of the bar hides
    # every item on macOS 27 (FelixKratz/SketchyBar#850).
    sketchybar = {
      url = "github:FelixKratz/SketchyBar/v2.24.1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      direnv-instant,
      nix-homebrew,
      fzf-tab-completion,
      sketchybar,
      ...
    }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] (
          system: f nixpkgs.legacyPackages.${system}
        );
      # Pinned dependencies enter through flake inputs at the entry point only.
      direnvInstantModule =
        { pkgs, ... }:
        {
          home.packages = [ direnv-instant.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        };
      fzfTabCompletionModule = {
        xdg.dataFile."fzf-tab-completion".source = fzf-tab-completion;
      };
      # Imported by both the home and the darwin modules, so the CLI and the
      # launchd service run the same build.
      sketchybarModule = {
        nixpkgs.overlays = [
          (final: prev: {
            sketchybar = prev.sketchybar.overrideAttrs {
              version = "2.24.1";
              src = sketchybar;
            };
          })
        ];
      };
      homeDarwinModule.imports = [
        ./nix/home/darwin.nix
        sketchybarModule
      ];
      darwinDefaultsModule.imports = [
        ./nix/darwin/defaults.nix
        sketchybarModule
      ];
      sharedHomeModules = [
        ./nix/home/activation.nix
        ./nix/home/cli.nix
        ./nix/home/git.nix
        ./nix/home/links.nix
        ./nix/home/ssh.nix
        ./nix/home/shell.nix
        ./nix/home/starship.nix
        ./nix/home/tools.nix
        direnvInstantModule
        fzfTabCompletionModule
      ];
      # nix-homebrew installs Homebrew itself during the darwin switch;
      # nix-homebrew.user is a machine fact that each host file sets.
      homebrewModule = {
        imports = [
          nix-homebrew.darwinModules.nix-homebrew
          ./nix/darwin/homebrew.nix
        ];
        nix-homebrew = {
          enable = true;
          # Adopt a curl-installed prefix, keeping its installed packages.
          autoMigrate = true;
          # env.sh runs brew shellenv with the Nix profile ordered first; the
          # integration would rerun it from /etc/zshrc and put brew first.
          enableZshIntegration = false;
          enableBashIntegration = false;
        };
      };
      # Base bootstrap profiles (install.md phase 1), one `base-<user>` output
      # per username the Macs use, with no other machine facts.
      baseUsers = [
        "jsyed"
        "generative"
      ];
      forBaseUsers =
        f: nixpkgs.lib.genAttrs' baseUsers (user: nixpkgs.lib.nameValuePair "base-${user}" (f user));
      baseHome = user: {
        home.username = user;
        home.homeDirectory = "/Users/${user}";
        home.stateVersion = "26.05";
        programs.home-manager.enable = true;
        dotfiles.repoDir = "/Users/${user}/code/jaza-syed/dotfiles";
      };
      baseDarwin = user: {
        nixpkgs.hostPlatform = "aarch64-darwin";
        system.primaryUser = user;
        users.users.${user}.home = "/Users/${user}";
        system.stateVersion = 6;
        nix-homebrew.user = user;
      };
    in
    {
      packages = forAllSystems (pkgs: {
        mermaid-cli = pkgs.callPackage ./nix/pkgs/mermaid-cli/package.nix { };

        # The repo source with the generated theme artifacts built in, for
        # hosts that set dotfiles.repoDir to a store path instead of a
        # checkout. scripts/generate_colorscheme.sh keeps producing them in a
        # checkout, where editing a palette needs no switch.
        sourceWithThemes =
          pkgs.runCommand "dotfiles-source-with-themes" { nativeBuildInputs = [ pkgs.lua5_4 ]; }
            ''
              cp -r ${self} $out
              chmod -R u+w $out
              cd $out
              lua palettes/generate.lua
            '';
      });

      homeModules = {
        default = {
          imports = sharedHomeModules;
        };
        activation = ./nix/home/activation.nix;
        cli = ./nix/home/cli.nix;
        darwin = homeDarwinModule;
        git = ./nix/home/git.nix;
        links = ./nix/home/links.nix;
        ssh = ./nix/home/ssh.nix;
        shell = ./nix/home/shell.nix;
        starship = ./nix/home/starship.nix;
        tools = ./nix/home/tools.nix;
      };

      darwinModules = {
        atrun = ./nix/darwin/atrun.nix;
        defaults = darwinDefaultsModule;
        homebrew = homebrewModule;
      };

      darwinConfigurations = forBaseUsers (
        user:
        nix-darwin.lib.darwinSystem {
          modules = [
            ./nix/darwin/atrun.nix
            darwinDefaultsModule
            homebrewModule
            (baseDarwin user)
          ];
        }
      );

      homeConfigurations = forBaseUsers (
        user:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          modules = sharedHomeModules ++ [
            homeDarwinModule
            (baseHome user)
          ];
        }
      );
    };
}

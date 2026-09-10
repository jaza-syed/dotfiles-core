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
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      direnv-instant,
      nix-homebrew,
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
      # Base bootstrap profiles (install.md phase 1): no machine facts beyond
      # the username and home directory, hard-coded by decision (AGENTS.md).
      baseHome = {
        home.username = "jsyed";
        home.homeDirectory = "/Users/jsyed";
        home.stateVersion = "26.05";
        programs.home-manager.enable = true;
        dotfiles.repoDir = "/Users/jsyed/code/jaza-syed/dotfiles";
      };
      baseDarwin = {
        nixpkgs.hostPlatform = "aarch64-darwin";
        system.primaryUser = "jsyed";
        users.users.jsyed.home = "/Users/jsyed";
        system.stateVersion = 6;
        nix-homebrew.user = "jsyed";
      };
    in
    {
      packages = forAllSystems (pkgs: {
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
        darwin = ./nix/home/darwin.nix;
        git = ./nix/home/git.nix;
        links = ./nix/home/links.nix;
        ssh = ./nix/home/ssh.nix;
        shell = ./nix/home/shell.nix;
        starship = ./nix/home/starship.nix;
        tools = ./nix/home/tools.nix;
      };

      darwinModules = {
        atrun = ./nix/darwin/atrun.nix;
        defaults = ./nix/darwin/defaults.nix;
        homebrew = homebrewModule;
      };

      darwinConfigurations.base = nix-darwin.lib.darwinSystem {
        modules = [
          ./nix/darwin/atrun.nix
          ./nix/darwin/defaults.nix
          homebrewModule
          baseDarwin
        ];
      };

      homeConfigurations.base = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = sharedHomeModules ++ [
          ./nix/home/darwin.nix
          baseHome
        ];
      };
    };
}

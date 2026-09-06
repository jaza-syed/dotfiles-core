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
      nixpkgs,
      home-manager,
      nix-darwin,
      direnv-instant,
      nix-homebrew,
      ...
    }:
    let
      # Pinned dependencies enter through flake inputs at the entry point only.
      direnvInstantModule = {
        home.packages = [ direnv-instant.packages.aarch64-darwin.default ];
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
        };
      };
      # Base bootstrap profiles (install.md phase 1): no machine facts beyond
      # the username and home directory, hard-coded by decision (ROADMAP 14).
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
      homeModules = {
        default = {
          imports = sharedHomeModules;
        };
        activation = ./nix/home/activation.nix;
        cli = ./nix/home/cli.nix;
        git = ./nix/home/git.nix;
        links = ./nix/home/links.nix;
        ssh = ./nix/home/ssh.nix;
        shell = ./nix/home/shell.nix;
        starship = ./nix/home/starship.nix;
        tools = ./nix/home/tools.nix;
      };

      darwinModules = {
        defaults = ./nix/darwin/defaults.nix;
        homebrew = homebrewModule;
      };

      darwinConfigurations.base = nix-darwin.lib.darwinSystem {
        modules = [
          ./nix/darwin/defaults.nix
          homebrewModule
          baseDarwin
        ];
      };

      homeConfigurations.base = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = sharedHomeModules ++ [ baseHome ];
      };
    };
}

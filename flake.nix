{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils/flatten-tree-system";
    nixpkgs.url = "github:NixOS/nixpkgs";
    neovim = {
      url = "github:QuentinI/nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-bundle = {
      url = "github:matthewbauer/nix-bundle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bundlers = {
      url = "github:NixOS/bundlers";
      inputs.nix-bundle.follows = "nix-bundle";
    };
  };

  outputs = { self, nixpkgs, flake-utils, neovim, bundlers, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zsh' = pkgs.callPackage ./zsh/default.nix { };

        topLevelPackages = pkgs:
        let
          neovim' = neovim.mkNeovim.${system} {
            inherit pkgs;
          };
          zsh' = pkgs.callPackage ./zsh/default.nix { };
          git' = pkgs.callPackage ./git.nix { };
        in with pkgs; [
          neovim'
          zsh'
          git'
          helix

          # Rust evangelism strike force
          xh bat duf exa fd ripgrep

          # Archive management
          atool unar unzip bzip2

          # System
          inetutils usbutils lshw htop psmisc

          # Git
          git github-cli

          # Data wrangling
          as-tree jq dsq difftastic

          # Multiplexing
          zellij tmate tmux

          # A little bit of everything
          busybox binutils coreutils file age gping
          pass patchelf picocom pv rlwrap tldr direnv
          progress
        ];
      in
      {
        homeManagerModules.default = { config, pkgs, ... }: { 
          home.packages = topLevelPackages pkgs;
        };

        nixosModules.default = { config, pkgs, ... }: {
          environment.systemPackages = topLevelPackages pkgs;
        };

        packages.default = pkgs.symlinkJoin {
          name = "shenv";

          paths = topLevelPackages pkgs;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postBuild = ''
            rm $out/bin/zsh

            makeWrapper "${zsh'}/bin/zsh" "$out/bin/zsh" \
             --suffix PATH : "$out/bin/"
          '';
        };

        bundlers.default = bundlers.bundlers.${system}.toArx;

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/zsh";
        };
      }
    );
}

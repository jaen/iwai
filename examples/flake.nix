{
  description = "Build Ruby apps the nix way";

  inputs = {
    nixpkgs = { url = "nixpkgs/nixpkgs-unstable"; };

    ### dev dependencies
    alejandra = { url = "github:kamadorueda/alejandra"; inputs.nixpkgs.follows = "nixpkgs"; };

    iwai = { url = "path:.."; inputs.nixpkgs.follows = "nixpkgs"; };

    dream2nix = { url = "github:jaen/dream2nix/extend-subsystems-wip"; inputs.nixpkgs.follows = "nixpkgs"; };

    flake-utils-plus = { url = "github:gytis-ivaskevicius/flake-utils-plus"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = {
    self,
    nixpkgs,
    alejandra,
    iwai,
    dream2nix,
    flake-utils-plus,
    ...
  } @ inputs: let
    inherit (flake-utils-plus.lib) defaultSystems eachDefaultSystem;

    dream2nix = inputs.dream2nix.lib.init {
      systems = defaultSystems;
      config ={
        inherit (iwai.lib.dream2nix.rubySubsystem) discoverers translators fetchers builders;

        projectRoot = ./.;
      };
    };

    dream2nixOutputs = (dream2nix.makeFlakeOutputs {
      source = ./.;
      settings = [ ];
    });
  in
    dream2nixOutputs //
    (eachDefaultSystem (system: 
      let
        mkShell = nixpkgs.legacyPackages.${system}.mkShell;
        ruby = nixpkgs.legacyPackages.${system}.ruby_3_1;
        devRuby = ruby.withPackages(ps: with ps; [ pry byebug pry-byebug ]);
      in {
      devShells = {
        default = mkShell {
          buildInputs = [
            devRuby.wrappedRuby
          ];
        };

        ruby = mkShell {
          buildInputs = [
            dream2nixOutputs.packages.${system}.ruby.wrappedRuby
          ];
        };

        ruby-git = mkShell {
          buildInputs = [
            dream2nixOutputs.packages.${system}.ruby-git.wrappedRuby
          ];
        };
      };
    }));
}
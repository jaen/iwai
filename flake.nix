{
  description = "Build Ruby apps the nix way";

  inputs = {
    nixpkgs = { url = "nixpkgs/nixpkgs-unstable"; };

    ### dev dependencies
    alejandra = { url = "github:kamadorueda/alejandra"; inputs.nixpkgs.follows = "nixpkgs"; };

    dream2nix = { url = "github:jaen/dream2nix/extend-subsystems"; inputs.nixpkgs.follows = "nixpkgs"; };

    flake-utils-plus = { url = "github:gytis-ivaskevicius/flake-utils-plus"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = {
    self,
    nixpkgs,
    alejandra,
    dream2nix,
    flake-utils-plus,
    ...
  } @ inputs: let
    inherit (flake-utils-plus.lib) defaultSystems eachDefaultSystem;

    dream2nix = inputs.dream2nix.lib.init {
      systems = defaultSystems;
      config ={
        inherit (import ./nix/ruby.nix {}) discoverers translators fetchers builders;

        projectRoot = ./example;
      };
    };

    dream2nixOutputs = (dream2nix.makeFlakeOutputs {
      source = ./example;
      settings = [ ];
    });
  in
    dream2nixOutputs //
    (eachDefaultSystem (system: {
      devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = [ dream2nixOutputs.packages.${system}.ruby.wrappedRuby ];
      };
    }));
}
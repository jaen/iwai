{
  description = "Build Ruby apps the nix way";

  inputs = {
    nixpkgs = { url = "nixpkgs/nixpkgs-unstable"; };

    ### dev dependencies
    alejandra = { url = "github:kamadorueda/alejandra"; inputs.nixpkgs.follows = "nixpkgs"; };

    dream2nix = { url = "github:jaen/dream2nix/extend-subsystems-wip"; inputs.nixpkgs.follows = "nixpkgs"; };

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

    # dream2nix = inputs.dream2nix.lib.init {
    #   systems = defaultSystems;
    #   config ={
    #     inherit (import ./nix/ruby.nix {}) discoverers translators fetchers builders;

    #     projectRoot = ./.;
    #   };
    # };

    # dream2nixOutputs = (dream2nix.makeFlakeOutputs {
    #   source = ./.;
    #   settings = [ ];
    # });

    lib = {
      dream2nix.rubySubsystem = import ./nix/ruby.nix {};
    };
  in
    {
      inherit lib;
    } // 
    # dream2nixOutputs //
    (eachDefaultSystem (system: 
      let
        mkShell = nixpkgs.legacyPackages.${system}.mkShell;
        ruby = nixpkgs.legacyPackages.${system}.ruby_3_1;
        devRuby = ruby.withPackages(ps: with ps; [ pry byebug pry-byebug ]);
      in{
        devShells = {
          default = mkShell {
            buildInputs = [
              devRuby.wrappedRuby
            ];
          };
      };
    }));
}

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

    lib = nixpkgs.lib;

    # rubySubsystem = nixpkgs.lib.trace "kek" (import ./nix/ruby.nix {});
    rubySubsystem = import ./nix/ruby.nix {};

    project = dream2nix.lib.init {
      systems = defaultSystems;
      config = {
        inherit (rubySubsystem) discoverers translators fetchers builders;

        projectRoot = ./.;
      };
    };

    dream2nixOutputs = (project.makeFlakeOutputs {
      source = ./sources;
      settings = [ ];
    });
  in
    {
      lib.dream2nix = {
        inherit rubySubsystem;
      };
    } // 
    dream2nixOutputs //
    (eachDefaultSystem (system: 
      let
        pkgs = nixpkgs.legacyPackages.${system};
        gemConfig = pkgs.defaultGemConfig // {
          nokogiri = attrs: ((pkgs.defaultGemConfig.nokogiri attrs) // {
            buildInputs = [ pkgs.zlib ];
          });
          rugged   = attrs: ((pkgs.defaultGemConfig.rugged attrs) // {
            buildInputs = [ pkgs.cmake ];

            postInstall = ''
              # clean up after build
              rm -rf $GEM_HOME/gems/rugged-${ attrs.version }/vendor;
              rm -rf $GEM_HOME/gems/rugged-${ attrs.version }/ext;
            '';
          });
        };
        mkShell = pkgs.mkShell;
        ruby = pkgs.ruby_3_1;
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

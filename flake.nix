{
  description = "Build Ruby apps the nix way";

  inputs = {
    nixpkgs = { url = "nixpkgs/nixpkgs-unstable"; };

    ### dev dependencies
    alejandra = { url = "github:kamadorueda/alejandra"; inputs.nixpkgs.follows = "nixpkgs"; };

    dream2nix = { url = "github:yusdacra/dream2nix/refactor/organize-code"; inputs.nixpkgs.follows = "nixpkgs"; };

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
        extra = {
            # subsystems.ruby = ./nix/ruby.nix;
            subsystems.ruby = {
              discoverers.ruby = ./nix/ruby/discoverer.nix;
              translators.bundler-impure = ./nix/ruby/translator.nix;
              builders.nixpkgs = ./nix/ruby/builder.nix;
              builders.default = ./nix/ruby/builder.nix;
            };

            # subsystems = {
            #   # ruby = rubySubsystem;
            #   ruby.discoverers.ruby = rubySubsystem.discoverers.ruby;
            #   ruby.translators.bundler-impure = rubySubsystem.translators.bundler-impure;
            #   ruby.builders.nixpkgs = rubySubsystem.builders.nixpkgs;
            # };
            # fetchers.rubygems = rubySubsystem.fetchers.rubygems;
            fetchers.rubygems = ./nix/ruby/fetcher.nix; # /default.nix;
          };

        projectRoot = ./.;
      };
    };

    dream2nixOutputs = (project.makeFlakeOutputs {
      source = ./sources;
      settings = [ ];
    });
  in
    # dream2nixOutputs;
    # {
    #   lib.dream2nix = {
    #     inherit rubySubsystem;
    #   };
    # } // 
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
      in {
        devShells = {
          default = mkShell {
            buildInputs = [
              devRuby.wrappedRuby
            ];
          };
      };
    }));
}

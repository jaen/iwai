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

    dream2nix = inputs.dream2nix.lib.init {
      systems = defaultSystems;
      config ={
        extra = [
          ./nix/ruby
        ];

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
    # (eachDefaultSystem (system: 
    #   let
    #     mkShell = nixpkgs.legacyPackages.${system}.mkShell;
    #     ruby = nixpkgs.legacyPackages.${system}.ruby_3_1;
    #     devRuby = ruby.withPackages(ps: with ps; [ pry byebug pry-byebug ]);
    #   in{
    #   devShells = {
    #     default = mkShell {
    #       buildInputs = [
    #         devRuby.wrappedRuby
    #       ];
    #     };

    #     ruby = mkShell {
    #       buildInputs = [
    #         dream2nixOutputs.packages.${system}.ruby.wrappedRuby
    #       ];
    #     };

    #     ruby-git = mkShell {
    #       buildInputs = [
    #         dream2nixOutputs.packages.${system}.ruby-git.wrappedRuby
    #       ];
    #     };
    #   };
    # }));
}
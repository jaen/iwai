{
  ruby = rec {
    default = nixpkgs;
    nixpkgs = {
        lib,
        pkgs,
        stdenv,
        # dream2nix inputs
        builders,
        externals,
        utils,
        makeBinaryWrapper,
        ...
      }: {
        # Funcs
        # AttrSet -> Bool) -> AttrSet -> [x]
        getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
        getDependencies, # name: version: -> [ {name=; version=; } ]
        getSource, # name: version: -> store-path
        buildPackageWithOtherBuilder, # { builder, name, version }: -> drv
        # Attributes
        subsystemAttrs, # attrset
        defaultPackageName, # string
        defaultPackageVersion, # string
        # attrset of pname -> versions,
        # where versions is a list of version strings
        packageVersions,
        # function which applies overrides to a package
        # It must be applied by the builder to each individual derivation
        # Example:
        #   produceDerivation name (mkDerivation {...})
        produceDerivation,
        # Custom Options: (parametrize builder behavior)
        # These can be passed by the user via `builderArgs`.
        # All options must provide default
        standalonePackageNames ? [],
        # overrides
        packageOverrides ? {},
        ...
      } @ args: let
        inherit (pkgs) buildRubyGem buildEnv;

        b = builtins;

        ruby = pkgs.ruby;
        bundler = pkgs.bundler;

        # # the main package
        # defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";

        # manage packages in attrset to prevent duplicated evaluation
        packages =
          lib.mapAttrs
          (name: versions:
            lib.genAttrs
            versions
            (version: makeOnePackage name version))
          packageVersions;

        gemFiles = getSource defaultPackageName defaultPackageVersion;

        # We have to normalize the Gemfile.lock, otherwise bundler tries to be
        # helpful by doing so at run time, causing executables to immediately bail
        # out. Yes, I'm serious.
        confFiles = pkgs.runCommand "gemfile-and-lockfile" {} ''
          mkdir -p $out
          echo ${gemFiles}
          ls -lah ${gemFiles}
          cp ${gemFiles}/Gemfile      $out/Gemfile      || ls -l $out/Gemfile
          cp ${gemFiles}/Gemfile.lock $out/Gemfile.lock || ls -l $out/Gemfile.lock
        '';

        gems = packages;

        envPaths = lib.concatMap lib.attrValues (lib.attrValues gems);

        defaultPackage = buildEnv {
          name = "${ defaultPackageName }-${ defaultPackageVersion }-gems";

          paths = envPaths;
          pathsToLink = [ "/lib" ];

          passthru = rec {
            inherit ruby bundler gems confFiles envPaths;

            wrappedRuby = stdenv.mkDerivation {
              name = "wrapped-ruby-${ defaultPackageName }-${ defaultPackageVersion }-gems";

              nativeBuildInputs = [ makeBinaryWrapper ];

              dontUnpack = true;

              buildPhase = ''
                mkdir -p $out/bin
                for i in ${ruby}/bin/*; do
                  makeWrapper "$i" $out/bin/$(basename "$i") \
                    --set BUNDLE_GEMFILE ${confFiles}/Gemfile \
                    --unset BUNDLE_PATH \
                    --set BUNDLE_FROZEN 1 \
                    --set GEM_HOME ${defaultPackage}/${ruby.gemPath} \
                    --set GEM_PATH ${defaultPackage}/${ruby.gemPath}
                done
              '';

              dontInstall = true;

              doCheck = true;
              checkPhase = ''
                $out/bin/ruby --help > /dev/null
              '';

              inherit (ruby) meta;
            };
          };
        };

        # Generates a derivation for a specific package name + version
        makeOnePackage = name: version: let
          pkg = buildRubyGem rec {
            inherit version;
            inherit ruby;

            pname = utils.sanitizeDerivationName name;

            gemName = name;

            src = getSource name version;

            buildInputs =
              map
              (dep: packages."${dep.name}"."${dep.version}")
              (getDependencies name version);

            # Implement build phases
          };
        in
          pkg;
          # TODO: doesn't work
          # (utils.applyOverridesToPackage packageOverrides pkg name);
      in {
        inherit defaultPackage;

        packages = packages // { ${defaultPackageName}.${defaultPackageVersion} = defaultPackage; };
      };
  };
}

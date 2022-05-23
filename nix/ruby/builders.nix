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
        defaultPackage = packages."${defaultPackageName}"."${defaultPackageVersion}";

        # manage packages in attrset to prevent duplicated evaluation
        packages =
          (lib.mapAttrs
          (name: versions:
            lib.genAttrs
            versions
            (version: makeOnePackage name version))
          # Filter out the leaf package because it won't build correctly;
          # TODO: I guess we need to store some metadata about whether to unpack or not
          #       and choose what to do with building the package, that way we won't have to build
          #       it separately
          packageVersions);
          # (lib.filterAttrs (name: _: name != defaultPackageName) packageVersions));
          # // { ${defaultPackageName}.${defaultPackageVersion} = defaultPackage; };

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

        # defaultPackage = buildEnv {
        #   name = "${ defaultPackageName }-${ defaultPackageVersion }-gems";

        #   paths = envPaths;
        #   pathsToLink = [ "/lib" ];

        #   passthru = rec {
        #     inherit ruby bundler gems confFiles envPaths;

        #     wrappedRuby = stdenv.mkDerivation {
        #       name = "wrapped-ruby-${ defaultPackageName }-${ defaultPackageVersion }-gems";

        #       nativeBuildInputs = [ makeBinaryWrapper ];

        #       dontUnpack = true;

        #       buildPhase = ''
        #         mkdir -p $out/bin
        #         for i in ${ruby}/bin/*; do
        #           makeWrapper "$i" $out/bin/$(basename "$i") \
        #             --set BUNDLE_GEMFILE ${confFiles}/Gemfile \
        #             --unset BUNDLE_PATH \
        #             --set BUNDLE_FROZEN 1 \
        #             --set GEM_HOME ${defaultPackage}/${ruby.gemPath} \
        #             --set GEM_PATH ${defaultPackage}/${ruby.gemPath}
        #         done
        #       '';

        #       dontInstall = true;

        #       doCheck = true;
        #       checkPhase = ''
        #         $out/bin/ruby --help > /dev/null
        #       '';

        #       inherit (ruby) meta;
        #     };
        #   };
        # };

        # TODO: learn how to use overrides for that
        gemConfig = pkgs.defaultGemConfig // {
          nokogiri = attrs: ((pkgs.defaultGemConfig.nokogiri attrs) // {
            buildInputs = [ pkgs.zlib ];
          });
          rugged   = attrs: ((pkgs.defaultGemConfig.rugged attrs) // {
            postInstall = ''
              # clean up after build
              rm -rf $GEM_HOME/gems/rugged-${ attrs.version }/vendor;
              rm -rf $GEM_HOME/gems/rugged-${ attrs.version }/ext;
            '';
          });
        };

        # Generates a derivation for a specific package name + version
        makeOnePackage = name: version: let
          sourceType = lib.traceValFn (x: "${name} is of type ${x}") (lib.attrByPath ["sourceTypes" name version] null subsystemAttrs);

          gemBuildAttrs = rec {
            inherit version ruby;
            
            type = "gem";

            pname = utils.sanitizeDerivationName name;

            gemName = name;

            # type = if sourceType == "rubygems" then "gem" else "git";

            dontUnpack = if sourceType == "gemspec" then true else "";
            # dontBuild = if sourceType != "rubygems" then true else "";

            src = lib.traceValFn (x: "${builtins.toJSON x}") (getSource name version);

            propagatedBuildInputs =
              # (lib.traceValFn (x: "Getting build inputs for ${name}@${version}: ${lib.concatStringsSep ", " (map (x: "${x.name}@${x.version}") (getDependencies name version))}") (
              map
              (dep: packages."${dep.name}"."${dep.version}")
              (getDependencies name version);
              # ));
          };

          git = pkgs.git;

          extraAttrs = if sourceType == "rubygems" then
              {}
            else if sourceType == "git" then
              {
                dontUnpack = true;
                dontBuild = false;
                preBuild =  ''
                  export gempkg=$src
                  echo "${name}: $gempkg"
                  cp -r $src/* .
                  cp $src/*.gemspec original.gemspec
                  gemspec=$(readlink -f .)/original.gemspec
                  ls -lah
                  ${git}/bin/git init
                  # remove variations to improve the likelihood of a bit-reproducible output
                  rm -rf .git/logs/ .git/hooks/ .git/index .git/FETCH_HEAD .git/ORIG_HEAD .git/refs/remotes/origin/HEAD .git/config
                  # support `git ls-files`
                  ${git}/bin/git add .
                '';
              }
            else if sourceType == "gemspec" then
              {
                dontUnpack = true;
                dontBuild = false;
                preBuild =  ''
                  set -x

                  export gempkg=$src
                  echo "${name}: $gempkg"
                  ls -lah $gempkg
                  # ls -lah $gempkg/..
                  cp -r $src/* .
                  echo "cp $src/*.gemspec original.gemspec"
                  cp $src/*.gemspec original.gemspec
                  gemspec=$(readlink -f .)/original.gemspec
                  ls -lah
                  ${git}/bin/git init
                  # remove variations to improve the likelihood of a bit-reproducible output
                  rm -rf .git/logs/ .git/hooks/ .git/index .git/FETCH_HEAD .git/ORIG_HEAD .git/refs/remotes/origin/HEAD .git/config
                  # support `git ls-files`
                  ${git}/bin/git add .
                '';
              }
            else
              throw "Unknown source type ${ sourceType } for gem ${ name }"; # TODO: check whether there's gemspec or not?

          # TODO: use dream2nix's override mechanism
          effectiveGemBuildAttrs = (if gemConfig ? ${name}
                                   then gemBuildAttrs // (gemConfig.${name} gemBuildAttrs)
                                   else gemBuildAttrs)  // extraAttrs;

          pkg = buildRubyGem (lib.traceValFn (x: "Building gem ${name} with attrs: ${builtins.toJSON x}") effectiveGemBuildAttrs);
        in
          pkg;
          # TODO: doesn't work
          # (utils.applyOverridesToPackage packageOverrides pkg name);
      in {
        inherit defaultPackage;

        packages = packages; # // { ${defaultPackageName}.${defaultPackageVersion} = defaultPackage; };
      };
  };
}

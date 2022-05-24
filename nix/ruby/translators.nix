{
  bundler-impure = ({ dlib, lib, name, ... }: 
    let
      translateBin = {
        # dream2nix
        externalSources,
        utils,
        bash,
        coreutils,
        curl,
        jq,
        nix,
        ruby_3_1,
        git,
        writeScriptBin,
        ...
      }: let
          ruby = ruby_3_1;
          rubyWithGems = (ruby.withPackages (ps: with ps; [ pry byebug pry-byebug ])).wrappedRuby;
        in
          (utils.writePureShellScript [ bash coreutils curl rubyWithGems nix git ] ''
            # according to the spec, the translator reads the input from a json file
            inputFile=$1

            cd $WORKDIR

            ${ ./generate_dream_lock.rb } "$@"
          '');
    in 
      {
        version = 2;

        # name = "bundler-impure";

        type = "impure";

        inherit translateBin name;

        extraArgs = {};
      }
  );
}

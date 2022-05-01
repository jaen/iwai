{
  ruby = {
    impure = {
      "bundler-impure" = ({ dlib, lib, }: 
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
            writeScriptBin,
            ...
          }: let
            in
              utils.writePureShellScript [ bash coreutils curl ruby_3_1 nix ] ''
                # according to the spec, the translator reads the input from a json file
                inputFile=$1

                cd $WORKDIR

                ${ ./generate_dream_lock.rb } "$@"
              '';
        in 
          {
            version = 2;

            inherit translateBin;

            extraArgs = {};
          }
      );
    };
  };
}

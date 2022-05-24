{
  ruby = { dlib, lib, subsystem, ... }:
    let
      l = lib // builtins;

      # Stolen from https://gist.github.com/schuelermine/195c33e22713703bd6651418f8f1ee96
      escapeRegex = str:
        l.foldl' (x: y: x + y) "" (map (char:
          if l.elem char [
            "["
            "]"
            "."
            "\\"
            "("
            ")"
            "+"
            "*"
            "?"
            "<"
            ">"
            ":"
            "-"
            "$"
            "^"
            "|"
          ] then
            "\\" + char
          else
            char) (l.foldl' (xs: ys: xs ++ ys) [ ]
              (map (x: if l.isList x then x else [ x ])
                (l.split "" str))));

      discover = args: #@{ tree }:
        let
          tree = l.trace "Discovering at $SOURCES/${ args.tree.relPath }" args.tree;
          
          subdirProjects =
            l.flatten
            (l.mapAttrsToList
              (dirName: dir: discover {tree = dir;})
              (tree.directories or {}));

          # A directory is identified as a project only if it contains a Gemfile
          # and a Gemfile.lock

          hasGemfile = tree ? files."Gemfile" && tree ? files."Gemfile.lock";
          gemspec = l.findFirst (file: (l.match ".*\.gemspec" file.name) != null) null (l.attrValues tree.files);
          hasGemspec = gemspec ? name;

          rubyProject = (tree ? files."Gemfile" && tree ? files."Gemfile.lock") || hasGemspec;

          # Very terrible way to look at the gemspec and see what the name is
          # TODO: this won't work if there's actual non-declarative code there, what to do about it?
          gemspecName = if hasGemspec
            then let 
                   gemSpecArgName = let
                                      gemSpecArgNameMatch = l.match ".+Specification\\.new[[:space:]]+do[[:space:]]+\\|([^|]+)\\|.+" gemspec.content;
                                      match               = if gemSpecArgNameMatch != null then (l.head gemSpecArgNameMatch) else null;
                                    in
                                      match;
                   gemName        = if gemSpecArgName != null then
                                      let
                                        gemNameMatch = l.match ".+[[:space:]]*${ escapeRegex gemSpecArgName }\.name[[:space:]]+=[[:space:]]+\"([^\"]+)\".+" gemspec.content;
                                        match         = if gemNameMatch != null then (l.head gemNameMatch) else null;
                                      in
                                        match
                                    else
                                      null;
                 in
                   if gemName != null
                   then gemName
                   else throw "Couldn't figure out gem name from gemspec for ${ gemspec.relPath }"
            else null;

          gemspecPath = gemspec.relPath or null;

          dirName = l.unsafeDiscardStringContext
                  (l.last
                    (l.splitString "/" (l.removeSuffix "/" "${ tree.fullPath }")));

          projectName =      if hasGemspec then gemspecName
                        else if hasGemfile then dirName
                        else null;

          projectTypeInfo = l.filter
                              (x: x != null)
                              [ (if hasGemfile then "gemfile" else null)
                                (if hasGemspec then "gemspec" else null) ];
        in
          # if rubyProject
          if lib.traceIf rubyProject "Discovered Ruby project (${ l.concatStringsSep ", " projectTypeInfo }) at: ${ tree.relPath }" rubyProject
          then
            [
              (dlib.construct.discoveredProject {
                inherit subsystem;
                relPath = tree.relPath;
                name = projectName;
                translators = [ "bundler-impure" ];
                subsystemInfo = {
                  inherit hasGemfile hasGemspec gemspecPath;
                };
              })
            ]
            ++ subdirProjects
          else subdirProjects;
      # discover = { tree }: let
      #   project = dlib.construct.discoveredProject {
      #     inherit subsystem;
      #     # weird that we can't have two identical relpaths
      #     # inherit (tree) relPath;
      #     relPath = "honk";
      #     name = "dummy-name";
      #     translators = [ "impure-dummy" ];
      #     subsystemInfo = {
      #       goose = "HONK!";
      #     };
      #   };
      # in
      #   [ project ];
    in {
      inherit discover;
    };
}

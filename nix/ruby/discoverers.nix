{
  ruby = { dlib, lib, subsystem, }:
    let
      l = lib // builtins;
      discover = {tree}:
        let
          x = l.traceIf true "Discovering at ${ lib.traceVal tree.relPath }" true;
          subdirProjects =
            l.flatten
            (l.mapAttrsToList
              (dirName: dir: discover {tree = dir;})
              (tree.directories or {}));

          # A directory is identified as a project only if it contains a Gemfile
          # and a Gemfile.lock
          rubyProject = tree
            ? files."Gemfile"
            && tree ? files."Gemfile.lock";
        in
          if rubyProject #  lib.traceIf rubyProject "Discovered Ruby project at: ${ tree.relPath }" rubyProject
          then
            [
              (dlib.construct.discoveredProject {
                inherit subsystem;
                relPath = tree.relPath;
                name =
                  l.unsafeDiscardStringContext
                  (l.last
                    (l.splitString "/" (l.removeSuffix "/" "${tree.fullPath}")));
                translators = [ "bundler-impure" ];
                subsystemInfo = {

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

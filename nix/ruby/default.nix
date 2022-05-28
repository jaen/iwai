{ lib, dlib, ... }@args:
  {
    subsystems.ruby = {
      discoverers = import ./discoverers args;
      translators = import ./translators args;
      builders    = import ./builders args;
    };

    fetchers = import ./fetchers args;
  }
  
{}:
  {
    discoverers = import ./ruby/discoverers.nix;
    translators = import ./ruby/translators.nix;
    fetchers    = import ./ruby/fetchers.nix; 
    builders    = import ./ruby/builders.nix;
  }
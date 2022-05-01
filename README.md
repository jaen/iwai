# Iwai

_There's no 仕方がない in our dictionary~!_

## What is it?

An attempt to modernise Ruby packaging for Nix(OS). While there's `buildRubyGem`, `bundix` and co. in nixpkgs,
the experience is… well, let's say charitably – less than stellar.

Some complaints from the top of my head:

  * only single patch version for a given `minor.major` version of Ruby – while this is quite the usual modus
    operandi for `nixpkgs` maintainers to rotate older versions out and probably not a big problem for Ruby
    apps packaged therein, it's not really all that convenient for developers. Practicalities of software
    development often mean being behind on runtime updates, with potentially multiple different versions
    across the projects and if you're in a monorepo, then you'd end up with multiple pinned nixpkgs
    versions which isn't very ergonomic,
    
  * `bundix` kind od works, until it doesn't – maybe your Ruby is too new and gem fetching fails, maybe it
    insists on install dev dependencies even though you want to package your app for production, maybe you
    want to develop a gem in a nix-provided development shell but `bundix` gets very confused at a `Gemfile`
    with a `gemspec` call? All real issues I've encountered and had to work around. And what is worse,
    `bundix` appears unmaintained so those issues just gather dust and cobwebs – for example I think there's
    three independent fixes for the first mentioned issue and none was ever merged,

  * `nixpkgs` language infrastructure is a set of disparate ivory towers, documentation is not always comprehensive
    and what there is, is often not really transferable between ecosystems. While it comes with the organic
    growth `nixpkgs` has experienced over time, it would be useful to modernise that part of the repository
    (and user experience) to foster better adoption among developers of those supported languages,

  * from what I've seen of the `nixpkgs` language infrastructure, it's usually not very modular – functions that
    could be useful outside those modules are often not exported to the top-level (which you can usually deal
    with using path imports) or are private to a `let` (which you really can't, save for forking). And while
    flake are new-fangled semi-beta not-always-well-baked (path imports of subflakes in monorepos, I'm looking
    at you), I feel it could be useful to split some parts of `nixpkgs`, such as language support, out as flakes.

Of course some of this can stem from a PEBKAC – while I have been using Nix(OS) for a while, I'm far from a
know-it-all – but I like to think that if you're not terribly dumb and after over a year with NixOS as a daily
driver you still wish language support had better ergonomics, then maybe there's some validity to that?

As such, it would be nice to have something that:

  * provides all the Rubies (within reason),
  * replaces `bundix` with a `dream2nix` subsystem as much as feasible, to provide a unified, working solution
    to locking down and fetching dependencies the nix way,
  * make the Ruby builds modular – if someone wants to reuse any parts of the build infrastructure for their
    needs (maybe their Ruby requirements fall outside "within reason"), they should be able to do so without
    having to muck about with direct path imports,
  * provide all this separately from `nixpkgs` and `dream2nix` as it's own flake, that you can mix & match when
    and where you need – if it will ever be useful enough to the respective upstreams, then maybe it could just
    be pulled in as a flake, serving as a good example of making `nixpkgs` more modular.

## Is this for real?

I don't know, maybe?

I generally have a very short attention span, but on the other hand this is something that annoys me personally
and would make a harder sell of nix as development infrastructure provider for my company. So I just kinda sorta
want to fix it, because while I can hardly come back to the world of mundane

## Does it even work?

Kinda?

You should be able to do `nix develop` and able to just `require "dry-schema"` in a REPL. And that's about
the extent of it for now.

Right now this is very barebones and no effort was made to have it work with anything other than the sample
`Gemfile` (there probably are some hard-coded assumptions). It also still re-uses most of `nixpkgs` packages
instead of providing own builds. It also requires a fork of `dream2nix` with extensibility hacked on – hopefully
it can serve as motivating use-case for upstream to consider this (probably with a better, overlay-based
interface than this hack).

## Related materials

* [another attempt to provide All The Rubies](https://github.com/bobvanderlinden/nixpkgs-ruby),
* [dream2nix](https://github.com/nix-community/dream2nix),
* [dream2nix extensiblity hack](https://github.com/jaen/dream2nix/tree/extend-subsystems).

## What's up with the name?

Apparently there's a variant of a Chinese fringe flower (_Loropetalum chinense_) that's called… Ruby Snow.
Yes, it's that simple – ruby means ruby, nix means snow. And that variant is apparently called _iwai_ in
Japanese. And since I'm a bit of a weeb and Ruby is a bit of a weeb language, then there you go. NERDS!

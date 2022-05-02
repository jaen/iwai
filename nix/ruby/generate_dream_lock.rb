#!/usr/bin/env ruby

require "bundler"
require "json"
require "fileutils"
require "set"
require "base64"

IWAI_DEV = true # ENV["IWAI_DEV"]

if IWAI_DEV
  require "pry"
  require "pry-byebug"
end


WORKDIR = Pathname(ENV["WORKDIR"] || Dir.pwd)

INPUT = if ARGV[0] && File.exist?(ARGV[0])
  JSON.parse(File.read(ARGV[0]))
else
  {}
end

puts "INPUT: #{ INPUT }" if IWAI_DEV
# INPUT: {"invalidationHash"=>"f784eb857205ae3ef62d110414a658e6636008eef944a9d01d83eef00075b61a", "outputFile"=>"dream2nix-packages/ruby/ruby/dream-lock.json", "project"=>{"dreamLockPath"=>"dream2nix-packages/ruby/ruby/dream-lock.json", "name"=>"ruby", "relPath"=>"ruby", "subsystem"=>"ruby", "subsystemInfo"=>{}, "translator"=>"bundler-impure", "translators"=>["bundler-impure"]}, "source"=>"/nix/store/xb3pi4vfwmw0a6sg4112vnnsy48lnfh6-abc"}

SOURCE_PATH = Pathname(INPUT.dig("source") || WORKDIR)
PROJECT_NAME = INPUT.dig("project", "name") || WORKDIR.basename
RELATIVE_PROJECT_PATH = Pathname(INPUT.dig("project", "relPath"))
PROJECT_PATH = INPUT.dig("project", "relPath") ? SOURCE_PATH.join(RELATIVE_PROJECT_PATH) : SOURCE_PATH
GEMFILE_LOCATION = PROJECT_PATH.join("Gemfile")
GEMFILE_LOCK_LOCATION = PROJECT_PATH.join("Gemfile.lock")
OUTPUT_LOCATION = Pathname(INPUT.dig("outputFile") || SOURCE_PATH.join("dream-lock.json"))

if IWAI_DEV
  puts "WORKDIR = #{ WORKDIR }"
  puts "SOURCE_PATH = #{ SOURCE_PATH }"
  puts "PROJECT_NAME = #{ PROJECT_NAME }"
  puts "PROJECT_PATH = #{ PROJECT_PATH }"
  puts "GEMFILE_LOCATION = #{ GEMFILE_LOCATION }"
  puts "GEMFILE_LOCK_LOCATION = #{ GEMFILE_LOCK_LOCATION }"
  puts "OUTPUT_LOCATION = #{ OUTPUT_LOCATION }"
end

BUNDLER_VERSION = Bundler::VERSION

ENV["BUNDLE_GEMFILE"] = GEMFILE_LOCATION.to_s

DEFINITION = Bundler::Definition.build(GEMFILE_LOCATION, GEMFILE_LOCK_LOCATION, false)

DEFINITION.resolve_remotely!
DEFINITION.missing_specs?

LOCKFILE = DEFINITION.locked_gems

ruby_version = LOCKFILE.ruby_version
bundler_version = LOCKFILE.bundler_version

platforms = LOCKFILE.platforms

nix_platforms = platforms.map { |p| "#{ p.cpu }-#{ p.os }" }

dependencies = LOCKFILE.dependencies.keys.to_set

generic_data = {
  "subsystem" => "ruby",
  "defaultPackage" => PROJECT_NAME,
  "translatorArgs" => "",
  "packages" => {
    PROJECT_NAME => "0.0.0"
  },
  "location" => RELATIVE_PROJECT_PATH.to_s,
  # TODO: what is this?
  "sourcesAggregatedHash" => nil,
}

# :Gemspec, :Metadata, :Path, :Rubygems, :Git
def source_type(source)
  case source
    when Bundler::Source::Rubygems; then :rubygems
    when Bundler::Source::Git;      then :git
    else 
      raise "Unknown source type #{ source.class.to_s }"
  end
end

subsystem_data = {
  "rubyVersion" => ruby_version.to_s,
  "bundleVersion" => bundler_version.to_s,
  "platforms" => nix_platforms,
}

# This has to be before `dependencies`
specs = LOCKFILE.specs

# Adapted from Gem::Dependency#matching_specs
# https://github.com/rubygems/rubygems/blob/bundler-v2.3.7/lib/rubygems/dependency.rb#L274-L289
def find_specs(dependency, platform_only: false)
  name = dependency.name
  requirement = dependency.requirement
  env_req = Gem.env_requirement(name)
  specs = LOCKFILE.specs
  
  matches = specs.find_all do |spec|
    spec.name == name && requirement.satisfied_by?(spec.version) && env_req.satisfied_by?(spec.version)
  end.map(&:to_spec)

  prioritizes_bundler = name == "bundler".freeze && !requirement.specific?

  Gem::BundlerVersionFinder.prioritize!(matches) if prioritizes_bundler

  if platform_only
    matches.reject! do |spec|
      spec.nil? || !Gem::Platform.match_spec?(spec)
    end
  end

  matches
end

dependencies_data = LOCKFILE.specs.map do |spec|
  name = spec.name
  deps = spec.dependencies.map do |dependency|
    dependency_specs = find_specs(dependency)

    raise "More then spec for #{ name }: #{ dependency_specs.inspect }" unless dependency_specs.size <= 1
    spec = dependency_specs.first 
    
    [ spec.name, spec.version.to_s ]
  end

  [ name, deps ]
end.to_h

def to_source_data(spec)
  name = spec.name
  version = spec.version.to_s
  source = spec.source
  type = source_type(source)

  print "Resolving #{ name }... "

  source_data = case type
    when :rubygems
      remote = source.remotes.first
      version_url = "#{ remote }api/v1/versions/#{ name }.json"
      entry = JSON.load(`curl "#{ version_url }" 2>/dev/null`).find { |e| e["number"] == version }

      # Load hash as binary string from hexadecimal repr
      sha = [entry["sha"]].pack("H*")
      url = "#{ remote }gems/#{ spec.full_name }.gem"

      puts "resolved to #{ version }"

      {
        "hash" => "sha256-#{ Base64.strict_encode64(sha) }",
        "type" => type,
        "url" => url
      }
    when :git
      revision = source.revision
      uri = source.uri

      puts "resolved to #{ revision } @ #{ version }"

      # TODO: could try to recognise GitHub

      {
        "type" => type,
        "rev" => revision,
        "url" => uri,
      }
  end
end

gem_sources_data = LOCKFILE.specs
  .group_by(&:name)
  .transform_values do |gem_specs|
    gem_specs
      .reduce({}) do |acc, spec|
        spec = spec.to_spec

        acc[spec.version.to_s] = to_source_data(spec)

        acc
      end
  end
  .to_h

output = {
  "_generic" => generic_data,
  "_subsystem" => subsystem_data,
  "depdendencies" => dependencies_data,
  "sources" => gem_sources_data,
}

FileUtils.mkdir_p(OUTPUT_LOCATION.dirname)

File.write(OUTPUT_LOCATION, JSON.pretty_generate(output))

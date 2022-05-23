#!/usr/bin/env ruby

require "bundler"
require "json"
require "fileutils"
require "set"
require "base64"

IWAI_DEV = true # ENV["IWAI_DEV"]

if false # IWAI_DEV
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

if IWAI_DEV
  SOURCE_PATH = Pathname(INPUT.dig("source") || WORKDIR)
  PROJECT_NAME = INPUT.dig("project", "name") || WORKDIR.basename
  RELATIVE_PROJECT_PATH = Pathname(INPUT.dig("project", "relPath") || "")
  PROJECT_PATH = INPUT.dig("project", "relPath") ? SOURCE_PATH.join(RELATIVE_PROJECT_PATH) : SOURCE_PATH
  SUBSYSTEM_INFO = INPUT.dig("project", "subsystemInfo") || {}
  GEMFILE_LOCATION = PROJECT_PATH.join("Gemfile")
  GEMFILE_LOCK_LOCATION = PROJECT_PATH.join("Gemfile.lock")
  GEMSPEC_LOCATION = SUBSYSTEM_INFO.dig("gemspecPath")
  OUTPUT_LOCATION = Pathname(INPUT.dig("outputFile") || SOURCE_PATH.join("dream-lock.json"))
else
  SOURCE_PATH = Pathname(INPUT.dig("source"))
  PROJECT_NAME = INPUT.dig("project", "name")
  RELATIVE_PROJECT_PATH = Pathname(INPUT.dig("project", "relPath"))
  PROJECT_PATH = Pathname(RELATIVE_PROJECT_PATH)
  SUBSYSTEM_INFO = INPUT.dig("project", "subsystemInfo") || {}
  GEMFILE_LOCATION = Pathname("Gemfile")
  GEMFILE_LOCK_LOCATION = Pathname("Gemfile.lock")
  GEMSPEC_LOCATION = SUBSYSTEM_INFO.dig("gemspecPath")
  OUTPUT_LOCATION = Pathname(INPUT.dig("outputFile"))
end

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

@nix_platforms = platforms.map { |p| "#{ p.cpu }-#{ p.os }" }

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
    when Bundler::Source::Gemspec;  then :gemspec
    when Bundler::Source::Git;      then :git
    else 
      raise "Unknown source type #{ source.class.to_s }"
  end
end

@subsystem_data = {
  "rubyVersion" => ruby_version.to_s,
  "bundlerVersion" => bundler_version.to_s,
  "platforms" => @nix_platforms,
  "gemspecPath" => GEMSPEC_LOCATION,
  "sourceTypes" => Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = {} } },
}

@resolved_bundler = nil

# Adapted from Gem::Dependency#matching_specs
# https://github.com/rubygems/rubygems/blob/bundler-v2.3.7/lib/rubygems/dependency.rb#L274-L289
def find_specs(dependency, platform_only: false)
  name = dependency.name
  requirement = dependency.requirement
  env_req = Gem.env_requirement(name)

  specs = if name == "bundler"
    remote_specs
  else
    DEFINITION.specs
  end

  matches = specs.find_all do |spec|
    spec.name == name && requirement.satisfied_by?(spec.version) && env_req.satisfied_by?(spec.version)
  end.map(&:to_spec)

  # binding.pry if name == "bundler"

  # prioritizes_bundler = name == "bundler" && !requirement.specific?

  # TODO: what about BUNDLED WITH?
  # Pick oldest
  if name == "bundler"
    if Gem::BundlerVersionFinder.respond_to?(:filter!)
      matches = Gem::BundlerVersionFinder.filter!(matches).take(1)
    elsif Gem::BundlerVersionFinder.respond_to?(:prioritize!)
      matches = Gem::BundlerVersionFinder.prioritize!(matches) .take(1)
    else
      raise "Dunno how to talk to BundlerVersionFinder"
    end

    @resolved_bundler = matches[0]
  end

  if platform_only
    matches.reject! do |spec|
      spec.nil? || !Gem::Platform.match_spec?(spec)
    end
  end

  matches
end

def local_specs
  @local_specs ||= Bundler::Source::Rubygems.new("allow_local" => true).specs.select {|spec| spec.name == "bundler" }
end

# [1] pry(main)> remotes = LOCKFILE.sources.find { |s| s.is_a?(Bundler::Source::Rubygems) }.remotes
# => [#<Bundler::URI::HTTPS https://rubygems.org/>]
# [2] pry(main)> source = Bundler::Source::Rubygems.new("remotes" => remotes)
# => #<Bundler::Source::Rubygems:0x1380 locally installed gems>
# [3] pry(main)> index = Bundler::Index.new
# => #<Bundler::Index:0x1400 sources=[] specs.size=0>
# [4] pry(main)> fetcher = source.send(:api_fetchers)[0]
# => #<Bundler::Fetcher:0x1460 uri=https://rubygems.org/>
# [5] pry(main)> fetcher.specs_with_retry(["bundler"], source).send(:specs)

def remote_specs
  @remote_specs ||= begin
    remotes = LOCKFILE.sources.find { |s| s.is_a?(Bundler::Source::Rubygems) }.remotes
    source = Bundler::Source::Rubygems.new("remotes" => remotes)
    source.remote!
    source.add_dependency_names(["bundler"])
    source.specs
  end
end

def find_latest_matching_spec_from_collection(specs, requirement)
  specs.sort.reverse_each.find {|spec| requirement.satisfied_by?(spec.version) }
end

def find_latest_matching_spec(requirement)
  local_result = find_latest_matching_spec_from_collection(local_specs, requirement)
  return local_result if local_result && requirement.specific?

  remote_result = find_latest_matching_spec_from_collection(remote_specs, requirement)
  return remote_result if local_result.nil?

  [local_result, remote_result].max
end

# TODO: maybe check if bundler needs to be added or not
dependencies_data = DEFINITION.specs
  .group_by(&:name)
  .transform_values do |specs|
    specs.reduce({}) do |acc, spec|
      acc[spec.version.to_s] = spec.dependencies.map do |dependency|
        dependency_specs = find_specs(dependency)

        raise "No specs found for #{ dependency.name }" if dependency_specs.empty?
        raise "More than one spec for #{ dependency.name }: #{ dependency_specs.inspect }" if dependency_specs.size > 1

        spec = dependency_specs.first

        [ spec.name, spec.version.to_s ]
      end

      acc
    end
  end

def to_source_data(spec)
  name = spec.name
  version = spec.version.to_s
  source = spec.source
  type = source_type(source)

  print "Resolving #{ name }... "

  @subsystem_data["sourceTypes"][name][version] = type

  source_data = case type
    when :rubygems
      remote = source.remotes.first
      version_url = "#{ remote }api/v1/versions/#{ name }.json"

      entry = JSON.load(`curl "#{ version_url }" 2>/dev/null`).find do |e|
        # TODO: handle different Ruby engines properly (get data from passthrough and put in project's subsystem attrs?)
        e["number"] == version && e["platform"] == "ruby"
      end

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
    when :gemspec
      # we need some way to resolve paths relative to the project root
      puts "path = #{ source.expanded_original_path }"
      puts "PROJECT_PATH = #{ PROJECT_PATH }"
      path = source.expanded_original_path.relative_path_from(SOURCE_PATH)
      # path = source.expanded_original_path

      puts "resolved to #{ path } @ #{ version }"

      {
        "type" => "path",
        "path" => path.to_s,
      }
  end
end

gem_sources_data = DEFINITION.specs
  .group_by(&:name)
  .transform_values do |gem_specs|
    gem_specs
      .reduce({}) do |acc, spec|
        specc = spec.to_spec

        # Restructure shit, so there's no need to rely on mutable state for that
        specc = @resolved_bundler if specc.name == "bundler"

        acc[specc.version.to_s] = to_source_data(specc)

        acc
      end
  end
  .to_h

output = {
  "_generic" => generic_data,
  "_subsystem" => @subsystem_data,
  "dependencies" => dependencies_data,
  "sources" => gem_sources_data,
}

FileUtils.mkdir_p(OUTPUT_LOCATION.dirname)

File.write(OUTPUT_LOCATION, JSON.pretty_generate(output))

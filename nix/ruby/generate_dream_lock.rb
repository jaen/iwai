#!/usr/bin/env ruby

require "bundler"
require "json"
require "fileutils"
require "set"
require "base64"

WORKDIR = ENV["WORKDIR"]

INPUT = if ARGV[0] && File.exist?(ARGV[0])
  JSON.parse(File.read(ARGV[0]))
else
  {}
end

puts "INPUT: #{ INPUT }"

# INPUT: {"invalidationHash"=>"f784eb857205ae3ef62d110414a658e6636008eef944a9d01d83eef00075b61a", "outputFile"=>"dream2nix-packages/ruby/ruby/dream-lock.json", "project"=>{"dreamLockPath"=>"dream2nix-packages/ruby/ruby/dream-lock.json", "name"=>"ruby", "relPath"=>"ruby", "subsystem"=>"ruby", "subsystemInfo"=>{}, "translator"=>"bundler-impure", "translators"=>["bundler-impure"]}, "source"=>"/nix/store/xb3pi4vfwmw0a6sg4112vnnsy48lnfh6-abc"}

SOURCE_PATH = Pathname(INPUT.dig("source") || "/home/jaen/Projects/nix/dream2nix/examples/abc")
PROJECT_PATH = Pathname(INPUT.dig("project", "relPath") || "/home/jaen/Projects/nix/dream2nix/examples/abc/project")
PROJECT_NAME = INPUT.dig("project", "name") || "ruby"
GEMFILE_LOCATION = SOURCE_PATH.join("ruby/Gemfile")
GEMFILE_LOCK_LOCATION = SOURCE_PATH.join("ruby/Gemfile.lock")
OUTPUT_LOCATION = Pathname(INPUT.dig("outputFile") || SOURCE_PATH.join("dream-lock.json"))

ENV["BUNDLE_GEMFILE"] = GEMFILE_LOCATION.to_s

gemfile_contents = File.read(GEMFILE_LOCATION)
lockfile_contents = File.read(GEMFILE_LOCK_LOCATION)
lockfile = Bundler::LockfileParser.new(lockfile_contents)
definition = Bundler::Definition.build(GEMFILE_LOCATION, GEMFILE_LOCK_LOCATION, false)

ruby_version = lockfile.ruby_version
bundler_version = lockfile.bundler_version

platforms = lockfile.platforms

nix_platforms = platforms.map { |p| "#{ p.cpu }-#{ p.os }" }

sources = lockfile.sources

dependencies = lockfile.dependencies.keys.to_set

specs = lockfile.specs

generic_data = {
  "subsystem" => "ruby",
  "defaultPackage" => PROJECT_NAME,
  "translatorArgs" => "",
  "packages" => {
    PROJECT_NAME => "0.0.0"
  },
  "location" => PROJECT_PATH.to_s,
  # TODO: what is this?
  "sourcesAggregatedHash" => nil,
}

subsystem_sources_data = sources.map do |source|
  source_name = source.class.name.split("::").last

  [ source_name, source.options ]
end.to_h

subsystem_data = {
  "rubyVersion" => ruby_version.to_s,
  "bundleVersion" => bundler_version.to_s,
  "platforms" => nix_platforms,
  "sources" => subsystem_sources_data,
}

dependencies_data = specs.map do |spec|
  name = spec.name
  deps = spec.dependencies.map do |dependency|
    dependency.name
  end

  [ name, deps ]
end.to_h

sources_data = specs
  .group_by(&:name)
  .map do |name, specs|
    puts "Resolving #{ name }..."
    sources = specs.map do |spec|
      version = spec.version.to_s
      remote = spec.source.remotes.first
      version_url = "#{ remote }api/v1/versions/#{ name }.json"
      entry = JSON.load(`curl "#{ version_url }" 2>/dev/null`).find { |e| e["number"] == version }
      # Load hash as binary string from hexadecimal repr
      sha = [entry["sha"]].pack("H*")
      url = "#{ remote }gems/#{ spec.full_name }.gem"
      # type = spec.source.class.name.split("::").last
      type = "rubygems"
      source_data = {
        "version" => version,
        "hash" => "sha256-#{Base64.strict_encode64(sha)}",
        "type" => type,
        "url" => url
      }

      # generic_data["packages"][name] = version if dependencies.include?(name)

      [ version, source_data ]
    end
    .to_h

    [ name, sources ]
  end
  .to_h

output = {
  "_generic" => generic_data,
  "_subsystem" => subsystem_data,
  "depdendencies" => dependencies_data,
  "sources" => sources_data,
}


FileUtils.mkdir_p(OUTPUT_LOCATION.dirname)

# File.open(OUTPUT_LOCATION, "w") do |f|
#   f.write(JSON.pretty_generate(output))
# end

File.write(OUTPUT_LOCATION, JSON.pretty_generate(output))

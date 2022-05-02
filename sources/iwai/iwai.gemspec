lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "iwai/version"

Gem::Specification.new do |spec|
  spec.name          = "iwai"
  spec.version       = Iwai::VERSION
  spec.authors       = ["Tomek Mańko"]
  spec.email         = ["jaennirin@gmail.com"]

  spec.summary       = %q{Build Ruby the nix way}
  spec.description   = %q{See README.md}
  spec.homepage      = "https://github.com/jaen/iwai"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "/dev/null"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/jaen/iwai"
    spec.metadata["changelog_uri"] = "https://github.com/jaen/iwai/blob/master/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  spec.files         = Dir[ "lib/**/*.rb" ] + [ "LICENSE.txt", "README.md", "CHANGELOG.md" ]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  spec.add_runtime_dependency "bundler", "~> 2.3.7"
  spec.add_runtime_dependency "rainbow"
  spec.add_runtime_dependency "git"
#   spec.add_runtime_dependency "rugged"
  spec.add_runtime_dependency "docile"
  spec.add_runtime_dependency "dry-cli"
  spec.add_runtime_dependency "dry-auto_inject"
  spec.add_runtime_dependency "dry-configurable"
  spec.add_runtime_dependency "dry-container"
  spec.add_runtime_dependency "dry-effects"
  spec.add_runtime_dependency "dry-equalizer"
  spec.add_runtime_dependency "dry-events"
  spec.add_runtime_dependency "dry-initializer"
  spec.add_runtime_dependency "dry-logic"
  spec.add_runtime_dependency "dry-matcher"
  spec.add_runtime_dependency "dry-monads"
  spec.add_runtime_dependency "dry-schema"
  spec.add_runtime_dependency "dry-struct"
  spec.add_runtime_dependency "dry-system"
  spec.add_runtime_dependency "dry-transaction"
  spec.add_runtime_dependency "dry-types"
  spec.add_runtime_dependency "dry-validation"
  spec.add_runtime_dependency "addressable"
  spec.add_runtime_dependency "semantic_logger"
  spec.add_runtime_dependency "psych"
  spec.add_runtime_dependency "rsync"
  spec.add_runtime_dependency "minitar"
  spec.add_runtime_dependency "concurrent-ruby"
  spec.add_runtime_dependency "concurrent-ruby-edge"
  spec.add_runtime_dependency "http"
  spec.add_runtime_dependency "zeitwerk"

  ## tty stuff
  spec.add_runtime_dependency "pastel"

  spec.add_runtime_dependency "tty-box"
  spec.add_runtime_dependency "tty-color"
  spec.add_runtime_dependency "tty-command"
  spec.add_runtime_dependency "tty-config"
  spec.add_runtime_dependency "tty-cursor"
  spec.add_runtime_dependency "tty-editor"
  spec.add_runtime_dependency "tty-file"
  spec.add_runtime_dependency "tty-font"
  spec.add_runtime_dependency "tty-logger"
  spec.add_runtime_dependency "tty-markdown"
  spec.add_runtime_dependency "tty-pager"
  spec.add_runtime_dependency "tty-pie"
  spec.add_runtime_dependency "tty-platform"
  spec.add_runtime_dependency "tty-progressbar"
  spec.add_runtime_dependency "tty-prompt"
  spec.add_runtime_dependency "tty-screen"
  spec.add_runtime_dependency "tty-spinner"
  spec.add_runtime_dependency "tty-table"
  spec.add_runtime_dependency "tty-tree"
  spec.add_runtime_dependency "tty-which"
#   spec.add_runtime_dependency "tty-runner"
end

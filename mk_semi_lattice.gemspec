# frozen_string_literal: true

require_relative "lib/mk_semi_lattice/version"

Gem::Specification.new do |spec|
  spec.name = "mk_semi_lattice"
  spec.version = MkSemiLattice::VERSION
  spec.authors = ["Shigeto R. Nishitani"]
  spec.email = ["shigeto_nishitani@me.com"]

  spec.summary = "make semi lattice graph from directory structure"
  spec.description = "make semi lattice graph from directory structure"
  spec.homepage = "https://github.com/daddygongon/mk_semi_lattice"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = 'https://rubygems.org'

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z],
                        chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "command_line"
  spec.add_runtime_dependency "colorize"
  spec.add_runtime_dependency "thor"
  spec.add_development_dependency "rake"
#  spec.add_dependency "ruby2d"
  spec.add_development_dependency "minitest-reporters"
end

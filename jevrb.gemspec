# frozen_string_literal: true

require_relative "lib/jevrb/version"

Gem::Specification.new do |spec|
  spec.name = "jevrb"
  spec.version = Jevrb::VERSION
  spec.authors = ["maful"]
  spec.email = ["me@maful.web.id"]

  spec.summary = "Ruby client for the TypeSafe System One API"
  spec.description = "Send typed questions to TypeSafe System One and receive typed Ruby response objects."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.homepage = "https://github.com/maful/jev"
  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/maful/jev/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["LICENSE", "README.md", "lib/**/*.rb", "sig/**/*.rbs"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end

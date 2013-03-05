# -*- encoding: utf-8; mode: ruby -*-
$:.push File.expand_path("../lib", __FILE__)
require "climax/version"

Gem::Specification.new do |s|
  s.name        = "climax"
  s.version     = Climax::VERSION
  s.authors     = ["Alfred J. Fazio"]
  s.email       = ["alfred.fazio@gmail.com"]
  s.homepage    = "https://github.com/appriss/climax"
  s.summary     = %q{Ruby command line application framework}
  s.description = %q{Opinionated framework for Ruby CLI applications that provides logging, cli argument parsing, daemonizing, configuration, testing, and even remote control of long running processes}

  s.rubyforge_project = "climax"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_development_dependency "cucumber"

  s.add_runtime_dependency "pry"
  s.add_runtime_dependency "slop"
  s.add_runtime_dependency "rspec"
  s.add_runtime_dependency "cucumber"
  s.add_runtime_dependency "pry-remote", '>= 0.1.7'
end

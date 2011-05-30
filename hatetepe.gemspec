# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hatetepe/version"

Gem::Specification.new do |s|
  s.name        = "hatetepe"
  s.version     = Hatetepe::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Lars Gierth"]
  s.email       = ["lars.gierth@gmail.com"]
  s.homepage    = "https://github.com/lgierth/hatetepe"
  s.summary     = %q{Builds and parses HTTP messages}
  s.description = %q{Hatetepe combines its own builder with http_parser.rb to make dealing with HTTP as comfortable as possible.}

  s.add_dependency "http_parser.rb"
  
  s.add_development_dependency "test-unit"

  s.files         = `git ls-files`.split("\n") - [".gitignore"]
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

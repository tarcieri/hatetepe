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
  s.summary     = %q{The HTTP toolkit}
  #s.description = %q{TODO: write description}

  s.add_dependency "http_parser.rb"
  s.add_dependency "eventmachine"
  s.add_dependency "em-synchrony"
  s.add_dependency "rack"
  s.add_dependency "async-rack"
  s.add_dependency "thor"
  
  s.add_development_dependency "rspec"
  s.add_development_dependency "fakefs"
  s.add_development_dependency "em-http-request"

  s.files         = `git ls-files`.split("\n") - [".gitignore"]
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

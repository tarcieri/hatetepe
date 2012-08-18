# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hatetepe/version"

Gem::Specification.new do |s|
  s.name        = "hatetepe"
  s.version     = Hatetepe::VERSION
  s.date        = Date.today.to_s
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Lars Gierth"]
  s.email       = ["lars.gierth@gmail.com"]
  s.homepage    = "https://github.com/lgierth/hatetepe"
  s.summary     = %q{The HTTP toolkit}
  #s.description = %q{TODO: write description}

  s.add_dependency "http_parser.rb", "~> 0.5.3"
  s.add_dependency "eventmachine",   "~> 1.0.0.beta.4"
  s.add_dependency "em-synchrony",   "~> 1.0"
  s.add_dependency "rack"
  s.add_dependency "thor"
  
  s.add_development_dependency "rspec"
  s.add_development_dependency "yard"
  s.add_development_dependency "kramdown"

  s.files         = `git ls-files`.split("\n") - [".gitignore", ".rspec", ".travis.yml", ".yardopts"]
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

require "bundler"
Bundler.setup :default

require "awesome_print"
require "hatetepe/server"

EM.synchrony {
  EM.epoll
  
  Signal.trap("INT") { EM.stop }
  Signal.trap("TERM") { EM.stop }
  
  Hatetepe::Server.start({
    :app => proc {|env|
      [200, {"Content-Type" => "text/plain"}, ["hallo!"]]
    },
    :host => "127.0.0.1",
    :port => 3000
  })
}

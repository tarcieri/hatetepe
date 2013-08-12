Hatetepe::Server::CONFIG_DEFAULTS[:app] = [ Hatetepe::Server::KeepAlive, Hatetepe::Server::RackApp ]

use Rack::ContentLength

run proc {|_|
  [200, {'Content-Type' => 'text/html'}, ['hello, world']]
}

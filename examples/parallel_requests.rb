require "hatetepe"
require "awesome_print"

EM.synchrony do
  # one server
  app = proc do |env|
    [200, {"Content-Type" => "text/plain"}, ["Hello, world!"]]
  end
  Hatetepe::Server.start :host => "127.0.0.1", :port => 3123, :app => app

  # two clients
  clients = 2.times.map { Hatetepe::Client.start :host => "127.0.0.1", :port => 3123 }

  # six requests
  requests = 6.times.map do |i|
    # no extra headers, empty body
    req = Hatetepe::Request.new(:get, "/", {}, [])

    # response status between 100 and 399
    req.callback {|res| puts "request ##{i} finished with #{res.status} response" }

    # response status between 400 and 599 or connection failure
    req.errback {|res| puts "request ##{i} finished with #{res ? res.status : 'no'} response" }

    clients[i % clients.length] << req
    req
  end

  # Client#stop waits until all of its requests have finished
  clients.map &:stop
  EM.stop
end

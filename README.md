The HTTP Toolkit
================

Hatetepe is a framework for building HTTP servers, clients and proxies using the
Ruby programming language. It makes use of EventMachine and uses a Fiber for
each request/response cycle to ensure maximum efficiency. It has some great
features that make it a good choice for building HTTP APIs.

Install it via `gem install hatetepe` or add `gem "hatetepe"` to your Gemfile.

Hatetepe only implements core HTTP functionality. If you need stuff like
automatic JSON or form-data encoding, have a look at
[Faraday](https://github.com/technoweenie/faraday), there's also an
[Hatetepe adapter](https://github.com/lgierth/faraday/tree/hatetepe-support)
for it being worked on.

[![Build status](https://secure.travis-ci.org/lgierth/hatetepe.png)](http://travis-ci.org/lgierth/hatetepe)


Getting Started (Server)
------------------------

Using Hatetepe as your HTTP server is easy. Simply use the CLI that ships with
the gem:

    $ hatetepe
    Booting from /home/lars/workspace/hatetepe/config.ru
    Binding to 127.0.0.1:3000

You can configure the network port and interface as well as the Rackup (.ru)
file to be used. More help is available via the `hatetepe help` command.


Getting Started (Client)
------------------------

The `Hatetepe::Client` class can be used to make requests to an HTTP server.

    client = Hatetepe::Client.start(:host => "example.org", :port => 80)
    request = Hatetepe::Request.new("POST", "/search", {}, :q => "herp derp")
    client << request
    request.callback do |response|
      puts "Results:"
      puts response.body.read
    end
    request.errback do |response|
      puts "Error Code: #{response.status}"
    end

`Request` and `Response` objects are mostly the same, they offer:

- `#verb` (only `Request`)
- `#uri` (only `Request`)
- `#status` (only `Response`)
- `#http_version`
- `#headers`
- `#body`

`Request` also has `#to_hash` which will turn the object into something your
app can respond to.


Async Responses
---------------

Like Thin and Goliath, Hatetepe provides `env["async.callback"]` for responding
in an asynchronous fashion. Don't forget to synchronously indicate an
asynchronous response by responding with a status of `-1`.

    def call(env)
      EM.add_timer(5) do
        env["async.callback"].call [200, {"Content-Type" => "text/html"}, ["Hello!"]]
      end
      [-1]
    end


Proxying
--------

Development of the Proxy functionality is still on-going - have a look at the
`proxy` branch for details.


Response Streaming
------------------

Streaming a response is easy. Just make your Rack app return a `-1` status code
and use the `stream.start`, `stream.send` and `stream.close` helpers.

    proc do |env|
      EM.add_timer 0.5 do
        env["stream.start"].call [200, {"Content-Type" => "text/plain"}]
      end
      
      1.upto 3 do |i|
        EM.add_timer i do
          env["stream.send"].call "I feel alive!\n"
          env["stream.close"].call if i == 3
        end
      end
      
      [-1]
    end

There's no limit on how long you can stream, keep in mind though that you might
hit timeouts. You can occasionally send LFs or something similar to prevent this
from happening.


Sending and Receiving BLOBs
---------------------------

Hatetepe provides a thin wrapper around StringIO that makes it easier to handle
streaming of request and response bodies. That means your app will be `#call`ed as
soon as all headers have arrived. It can then do stuff while it's still
receiving body data. You might for example want to track upload progress.

    received = nil
    total = nil

    post "/upload" do
      total = request.headers["Content-Length"].to_i
      request.env["rack.input"].each do |chunk|
        received += chunk.bytesize
      end
      request.env["rack.input"].rewind
    end
    
    get "/progress" do
      json [received, total]
    end

`Hatetepe::Body#each` will block until the response has been received completely
and yield each time a new chunk arrives. Calls to `#read`, `#gets` and `#length`
will block until everything arrived and then return their normal return value
as expected. `Body` includes `EM::Deferrable`, meaning you can attach
callbacks to it. `#close_write` will succeed it - this is important if you
want to make a request with a streaming body.


Contributing
------------

1. Fork at [github.com/lgierth/hatetepe](https://github.com/lgierth/hatetepe)
2. Create a new branch
3. Commit, commit, commit!
4. Open a Pull Request

You can also open an issue for discussion first, if you like.


License
-------

Hatetepe is subject to an MIT-style license (see LICENSE file).


To Do and Ideas
---------------

- Proxy
- Code reloading
- Keep-alive
- Native file sending/receiving
- Preforking
- MVM support via Thread Pool
- Support for SPDY
- Serving via filesystem or in-memory
- Foreman support
- Daemonizing and dropping privileges
- Trailing headers
- Propagating connection errors to the app

- Fix http_parser.rb's parsing of chunked bodies
- Does http_parser.rb recognize trailing headers?
- Encoding support (see https://github.com/tmm1/http_parser.rb/pull/1)
- Are there any good C libs for building HTTP messages?

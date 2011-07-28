require "eventmachine"
require "uri"

require "hatetepe/client"

module Hatetepe
  class Proxy
    attr_reader :app, :env
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      @env = env
      env["proxy.start"] = method(:start)
      
      app.call env
    end
    
    def start(target)
      uri = build_uri(target)
      
      env.delete "proxy.start"
      env["proxy.callback"] ||= method(:callback)
      
      response = Client.request(verb, uri, headers)
      env["proxy.callback"].call @response, env
    end
    
    def callback(response, env)
      response
    end
  end
end

module Hatetepe
  class OldProxy
    attr_reader :env, :target
    
    def initialize(env, target)
      client = EM.connect target.host, target.port, Client
      client.request env["rity.request"].verb, env["rity.request"].uri
      
      env["proxy.callback"] ||= proc {|response|
        env["proxy.start_reverse"].call response
      }
      env["proxy.start_reverse"] = proc {|response|
        env["stream.start"].call *response[0..1]
        env["stream.send_raw"].call client.requests
      }
    end
    
    def initialize(env, target)
      response = Client.request(env["rity.request"])
    end
  end
end

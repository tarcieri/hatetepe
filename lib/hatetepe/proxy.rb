require "hatetepe/client"
require "uri"

module Hatetepe
  class Proxy
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      env["proxy.start"] = proc do |target, client = nil|
        start env, target, client
      end
      app.call env
    end
    
    def start(env, target, client)
      target = URI.parse(target)
      env.delete "proxy.start"
      
      env["proxy.start_reverse"] ||= env["async.callback"]
      env["proxy.callback"] ||= env["proxy.start_reverse"]
      
      cl = client || Client.start(:host => target.host, :port => target.port)
      env["hatetepe.request"].dup.tap {|req|
        cl << req
        EM::Synchrony.sync req
        cl.stop unless client
        env["proxy.callback"].call req.response
      }
    end
  end
end

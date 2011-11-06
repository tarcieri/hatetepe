require "hatetepe/client"
require "hatetepe/request"
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
      
      env["proxy.callback"] ||= env["async.callback"]
      
      cl = client || Client.start(:host => target.host, :port => target.port)
      build_request(env, target).tap do |req|
        cl << req
        EM::Synchrony.sync req
        req.response.body.callback { cl.stop } unless client
        env["proxy.callback"].call req.response
      end
    end
    
    # TODO use only +env+ to build the request
    def build_request(env, target)
      unless base = env["hatetepe.request"]
        raise ArgumentError, "Proxying requires env[hatetepe.request] to be set"
      end
      
      uri = target.path + base.uri
      host = "#{target.host}:#{target.port}"
      Request.new(base.verb, uri, base.http_version).tap do |req|
        req.headers = base.headers.merge("Host" => host)
        req.body = base.body
      end
    end
  end
end

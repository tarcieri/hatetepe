require "async-rack"
require "rack"

Rack::STREAMING = "Rack::STREAMING"

module Hatetepe
  class App
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      env["async.callback"] = proc {|response|
        postprocess env, response
      }
      env["async.callback"].call app.call(env)
    end
    
    def postprocess(env, response)
      return if response[0] < 0
      
      env["stream.start"].call response[0..1]
      return if response[2] == Rack::STREAMING
      
      response[2].each {|chunk| env["stream.send"].call chunk }
      env["stream.close"].call
    end
  end
end

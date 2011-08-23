require "async-rack"
require "rack"

Rack::STREAMING = "Rack::STREAMING"

module Hatetepe
  ASYNC_RESPONSE = [-1, {}, []].freeze
  
  ERROR_RESPONSE = [500, {"Content-Type" => "text/html"},
                    ["Internal Server Error"]].freeze
  
  class App
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      env["async.callback"] = proc {|response|
        postprocess env, response
      }
      
      response = ASYNC_RESPONSE
      catch(:async) {
        response = app.call(env) rescue ERROR_RESPONSE
      }
      postprocess env, response
    end
    
    def postprocess(env, response)
      return if response[0] == ASYNC_RESPONSE[0]
      
      env["stream.start"].call response[0..1]
      return if response[2] == Rack::STREAMING
      
      begin
        response[2].each {|chunk| env["stream.send"].call chunk }
      ensure
        env["stream.close"].call
      end
    end
  end
end

require "async-rack"
require "rack"

Rack::STREAMING = "Rack::STREAMING"

module Hatetepe
  ASYNC_RESPONSE = [-1, {}, []].freeze
  
  ERROR_RESPONSE = [500, {"Content-Type" => "text/html"},
                    ["Internal Server Error"]].freeze
  
  # Interface between Rack-compatible applications and Hatetepe's server.
  # Provides support for both synchronous and asynchronous responses.
  class App
    attr_reader :app
    
    # Initializes a new App object.
    #
    # @param [#call] app
    #   The Rack app
    #
    def initialize(app)
      @app = app
    end
    
    # Processes the request.
    #
    # Will call #postprocess with the Rack app's response. Catches :async
    # as an additional indicator for an asynchronous response. Uses a standard
    # 500 response if the Rack app raises an error.
    #
    # @param [Hash] env
    #   The Rack environment
    #
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
    
    # Sends the response.
    #
    # Does nothing if response status is indicating an asynchronous response.
    # This is the case if the response Array's first element equals -1.
    # Otherwise it will start sending the response (status and headers).
    #
    # If the body indicates streaming it will return after sending the status
    # and headers. This happens if the body equals Rack::STREAMING. Otherwise
    # it sends each body chunk and then closes the response stream.
    #
    # @param [Hash] env
    #   The Rack environment
    # @param [Array] response
    #   An array of 1..3 length containing the status, headers, body
    #
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

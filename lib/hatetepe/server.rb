require "eventmachine"
require "em-synchrony"

require "hatetepe/app"
require "hatetepe/builder"
require "hatetepe/connection"
require "hatetepe/parser"
require "hatetepe/prefork"
require "hatetepe/proxy"
require "hatetepe/request"

module Hatetepe
  class Server < Connection
    def self.start(config)
      server = EM.start_server(config[:host], config[:port], self, config)
      Prefork.manage server if config[:prefork]
    end
    
    attr_reader :app, :log, :requests
    
    def initialize(config)
      @app, @log = App.new(config[:app]), config[:log]
      set_comm_inactivity_timeout config[:timeout]
      
      super
    end
    
    def post_init
      @requests = []
      @parser, @builder = Parser.new, Builder.new
      
      @parser.on_request {|verb, uri|
        requests << Request.new(verb, uri)
      }
      
      @parser.on_headers_complete {|headers|
        previous, request = requests[-2], requests[-1]
        
        request.headers = headers
        env = request.to_hash.tap {|e|
          e["rity.connection"] = self
          e["rity.request"] = request
          e["rity.raw_headers"] = @raw_request[0]
          e["rity.raw_body"] = @raw_request[1]
          
          e["stream.start"] = proc {|response|
            EM::Synchrony.sync previous if previous
            @builder.response *response[0..1]
          }
          
          e["stream.send"] = proc {|chunk|
            @builder.body_chunk chunk
          }
          
          e["stream.close"] = proc {
            @builder.complete
            request.succeed
            requests.delete request
          }
          
          e["proxy.start"] = proc {|target|
            e["rity.proxy"] = Proxy.new(env, target)
          }
        }
        
        pause
        request.body.lock.callback {
          e["rity.raw_body"].close_write
          resume
        }
        
        Fiber.new { app.call env }.resume
      }
      
      @parser.on_body_chunk {|chunk| request.body << chunk }
      @parser.on_complete { request.body.close_write }
      
      @builder.on_write {|data| send_data data }
    end
    
    def receive_data(data)
      @parser << data
    end
  end
end

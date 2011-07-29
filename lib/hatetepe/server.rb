require "eventmachine"
require "em-synchrony"
require "rack"

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
      Prefork.run server if config[:prefork]
    end
    
    attr_reader :app, :log, :requests
    
    def initialize(config)
      @app = Rack::Builder.app {
        use Hatetepe::App
        use Hatetepe::Proxy
        run config[:app]
      }
      @log = config[:log]

      super
      set_comm_inactivity_timeout config[:timeout] || 30
    end
    
    def post_init
      @requests = []
      @parser, @builder = Parser.new, Builder.new
      
      @parser.on_request &requests.method(:<<)
      @parser.on_headers &method(:process)

      @builder.on_write &method(:send_data)
      #@builder.on_write {|data| puts data; send_data(data) }
    end
    
    def receive_data(data)
      #puts data
      @parser << data
    rescue ParserError
      close_connection
    end
    
    def process(*)
      previous, request = requests.values_at(-2, -1)
      
      env = request.to_hash.tap {|e|
        e["hatetepe.connection"] = self
        
        e["stream.start"] = proc {|response|
          previous.sync if previous
          response[1]["Server"] = "hatetepe/#{VERSION}"
          @builder.response response[0..1]
        }
        
        e["stream.send"] = @builder.method(:body)
        
        e["stream.close"] = proc {
          @builder.complete
          requests.delete request
          request.succeed
          
          close_connection_after_writing if requests.empty?
        }
      }
      
      Fiber.new { app.call env }.resume
    end
  end
end

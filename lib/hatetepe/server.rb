require "eventmachine"
require "em-synchrony"
require "rack"

require "hatetepe/app"
require "hatetepe/builder"
require "hatetepe/parser"
require "hatetepe/request"

module Hatetepe
  class Server < EM::Connection
    def self.start(config)
      server = EM.start_server(config[:host], config[:port], self, config)
      #Prefork.run server if config[:prefork]
    end
    
    attr_reader :app, :log, :config
    attr_reader :requests, :parser, :builder
    
    def initialize(config)
      @app = Rack::Builder.new.tap {|b|
        b.use Hatetepe::App
        #b.use Hatetepe::Proxy
        b.run config[:app]
      }
      @log = config[:log]

      @config = config
      super
    end
    
    def post_init
      @requests = []
      @parser, @builder = Parser.new, Builder.new
      
      parser.on_request << requests.method(:<<)
      parser.on_headers << method(:process)

      builder.on_write << method(:send_data)
    end
    
    def receive_data(data)
      parser << data
    rescue ParserError
      close_connection
    end
    
    def process(*)
      previous, request = requests.values_at(-2, -1)
      
      env = request.to_hash.tap {|e|
        e["hatetepe.connection"] = self
        e["rack.input"].source = self
        
        e["SERVER_NAME"] = config[:host].dup
        e["SERVER_PORT"] = String(config[:port])
        
        host = e["HTTP_HOST"] || config[:host].dup
        host += ":#{config[:port]}" unless host.include? ":"
        e["HTTP_HOST"] = host
        
        e["stream.start"] = proc {|response|
          EM::Synchrony.sync previous if previous
          response[1]["Server"] = "hatetepe/#{VERSION}"
          builder.response response[0..1]
        }
        
        e["stream.send"] = builder.method(:body)
        
        e["stream.close"] = proc {
          builder.complete
          requests.delete request
          request.succeed
          
          close_connection_after_writing if requests.empty?
        }
      }
      
      Fiber.new { app.call env }.resume
    end
  end
end

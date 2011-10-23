require "eventmachine"
require "em-synchrony"
require "rack"

require "hatetepe/app"
require "hatetepe/builder"
require "hatetepe/parser"
require "hatetepe/request"
require "hatetepe/version"

module Hatetepe
  class Server < EM::Connection
    def self.start(config)
      server = EM.start_server(config[:host], config[:port], self, config)
      #Prefork.run server if config[:prefork]
    end
    
    attr_reader :app, :config, :errors
    attr_reader :requests, :parser, :builder
    
    def initialize(config)
      @config = config
      @errors = config[:errors] || $stderr
      
      @app = Rack::Builder.new.tap {|b|
        b.use Hatetepe::App
        #b.use Hatetepe::Proxy
        b.run config[:app]
      }

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
    rescue Exception => ex
      close_connection_after_writing
      backtrace = ex.backtrace.map {|line| "\t#{line}" }.join("\n")
      errors << "#{ex.class}: #{ex.message}\n#{backtrace}\n"
      errors.flush
    end
    
    def process(*)
      previous, request = requests.values_at(-2, -1)
      
      env = request.to_hash.tap {|e|
        e["hatetepe.connection"] = self
        e["rack.url_scheme"] = "http"
        e["rack.input"].source = self
        e["rack.errors"] = errors
        
        e["rack.multithread"] = false
        e["rack.multiprocess"] = false
        e["rack.run_once"] = false
        
        e["SERVER_NAME"] = config[:host].dup
        e["SERVER_PORT"] = String(config[:port])
        
        host = e["HTTP_HOST"] || config[:host].dup
        host += ":#{config[:port]}" unless host.include? ":"
        e["HTTP_HOST"] = host
        
        e["stream.start"] = proc {|response|
          e.delete "stream.start"
          EM::Synchrony.sync previous if previous
          
          builder.response_line response[0]
          response[1]["Server"] = "hatetepe/#{VERSION}"
          builder.headers response[1]
        }
        
        e["stream.send"] = builder.method(:body)
        
        e["stream.close"] = proc {
          e.delete "stream.send"
          e.delete "stream.close"
          
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

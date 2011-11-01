require "eventmachine"
require "em-synchrony"
require "rack"

require "hatetepe/app"
require "hatetepe/builder"
require "hatetepe/parser"
require "hatetepe/pipeline"
require "hatetepe/proxy"
require "hatetepe/request"
require "hatetepe/version"

module Hatetepe
  class Server < EM::Connection
    def self.start(config)
      EM.start_server config[:host], config[:port], self, config
    end
    
    attr_reader :app, :config, :errors
    attr_reader :requests, :parser, :builder
    
    def initialize(config)
      @config = config
      @errors = config[:errors] || $stderr

      @app = Rack::Builder.app do
        use Hatetepe::Pipeline
        use Hatetepe::App
        use Hatetepe::Proxy
        run config[:app]
      end

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
      request = requests.last
      
      env = request.to_hash.tap do |e|
        inject_environment e
        e["stream.start"] = proc do |response|
          e.delete "stream.start"
          start_response response
        end
        e["stream.send"] = builder.method(:body_chunk)
        e["stream.close"] = proc do
          e.delete "stream.start"
          e.delete "stream.send"
          close_response request
        end
      end
      
      Fiber.new { app.call env }.resume
    end
    
    def start_response(response)
      builder.response_line response[0]
      response[1]["Server"] = "hatetepe/#{VERSION}"
      builder.headers response[1]
    end
    
    def close_response(request)
      builder.complete
      requests.delete request
      close_connection_after_writing if requests.empty?
    end
      
    def inject_environment(env)
      env["hatetepe.connection"] = self
      env["rack.url_scheme"] = "http"
      env["rack.input"].source = self
      env["rack.errors"] = errors
      
      env["rack.multithread"] = false
      env["rack.multiprocess"] = false
      env["rack.run_once"] = false
      
      env["SERVER_NAME"] = config[:host].dup
      env["SERVER_PORT"] = String(config[:port])
      
      host = env["HTTP_HOST"] || config[:host].dup
      host += ":#{config[:port]}" unless host.include? ":"
      env["HTTP_HOST"] = host
    end
  end
end

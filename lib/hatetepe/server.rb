require "eventmachine"
require "em-synchrony"
require "rack"

require "hatetepe/builder"
require "hatetepe/parser"
require "hatetepe/version"

module Hatetepe
  class Server < EM::Connection; end
end

require "hatetepe/server/app"
require "hatetepe/server/pipeline"
require "hatetepe/server/proxy"

class Hatetepe::Server
  def self.start(config)
    EM.start_server config[:host], config[:port], self, config
  end
  
  attr_reader :app, :config, :errors
  attr_reader :requests, :parser, :builder
  
  def initialize(config)
    @config = config
    @errors = config[:errors] || $stderr

    @app = Rack::Builder.new.tap do |b|
      b.use Pipeline
      b.use App
      b.use Proxy
      b.run config[:app]
    end.to_app

    super
  end
  
  def post_init
    @requests = []
    @parser, @builder = Hatetepe::Parser.new, Hatetepe::Builder.new
    
    parser.on_request << requests.method(:<<)
    parser.on_headers << method(:process)

    builder.on_write << method(:send_data)
  end
  
  def receive_data(data)
    parser << data
  rescue Hatetepe::ParserError
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
        e.delete "stream.send"
        e.delete "stream.close"
        close_response request
      end
    end
    
    Fiber.new { app.call env }.resume
  end
  
  def start_response(response)
    builder.response_line response[0]
    response[1]["Server"] ||= "hatetepe/#{Hatetepe::VERSION}"
    builder.headers response[1]
  end
  
  def close_response(request)
    builder.complete
    requests.delete request
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
    env["REMOTE_ADDR"] = remote_address.dup
    env["REMOTE_PORT"] = String(remote_port)
    
    host = env["HTTP_HOST"] || config[:host].dup
    host += ":#{config[:port]}" unless host.include? ":"
    env["HTTP_HOST"] = host
  end
  
  def remote_address
    sockaddr && sockaddr[1]
  end
  
  def remote_port
    sockaddr && sockaddr[0]
  end
  
  private
  
  def sockaddr
    @sockaddr ||= Socket.unpack_sockaddr_in(get_peername) rescue nil
  end
end

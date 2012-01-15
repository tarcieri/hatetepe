require "eventmachine"
require "em-synchrony"
require "rack"

require "hatetepe/builder"
require "hatetepe/connection"
require "hatetepe/parser"
require "hatetepe/strings"

module Hatetepe
  class Server < Hatetepe::Connection; end
end

require "hatetepe/server/app"
require "hatetepe/server/keep_alive"
require "hatetepe/server/pipeline"
require "hatetepe/server/proxy"

class Hatetepe::Server
  include Hatetepe::Strings

  def self.start(config)
    EM.start_server config[:host], config[:port], self, config
  end
  
  attr_reader :app, :config, :errors
  attr_reader :requests, :parser, :builder
  
  def initialize(config)
    @config = {:timeout => 1}.merge(config)
    @errors = @config.delete(:errors) || $stderr

    super
  end
  
  def post_init
    @requests = []
    @parser, @builder = Hatetepe::Parser.new, Hatetepe::Builder.new
    
    parser.on_request << requests.method(:<<)
    parser.on_headers << method(:process)

    # XXX check if the connection is still present
    builder.on_write << method(:send_data)
    #builder.on_write {|data| p "server >> #{data}" }

    @app = Rack::Builder.new.tap do |b|
      # middleware is NOT ordered alphabetically
      b.use Pipeline
      b.use App
      b.use KeepAlive
      b.use Proxy
      b.run config[:app]
    end.to_app
    
    self.processing_enabled = true
    self.comm_inactivity_timeout = config[:timeout]
  end
  
  def receive_data(data)
    #p "server << #{data}"
    parser << data
  rescue Hatetepe::ParserError => ex
    close_connection
    raise ex if ENV[STR_RACK_ENV] == STR_TESTING
  rescue Exception => ex
    close_connection_after_writing
    backtrace = ex.backtrace.map {|line| "\t#{line}" }.join("\n")
    errors << "#{ex.class}: #{ex.message}\n#{backtrace}\n"
    errors.flush
    raise ex if ENV[STR_RACK_ENV] == STR_TESTING
  end
  
  # XXX fail response bodies properly
  # XXX make sure no more data is sent
  def unbind
    super
    #requests.map(&:body).each &:fail
  end
  
  def process(*)
    return unless processing_enabled?
    request = requests.last
    
    self.comm_inactivity_timeout = 0
    reset_timeout = proc do
      self.comm_inactivity_timeout = config[:timeout] if requests.empty?
    end
    request.callback &reset_timeout
    request.errback &reset_timeout
    
    env = request.to_h.tap do |e|
      inject_environment e
      e[STR_STREAM_START] = proc do |response|
        e.delete STR_STREAM_START
        start_response response
      end
      e[STR_STREAM_SEND] = builder.method(:body_chunk)
      e[STR_STREAM_CLOSE] = proc do
        e.delete STR_STREAM_SEND
        e.delete STR_STREAM_CLOSE
        close_response request
      end
    end
    
    Fiber.new { app.call env }.resume
  end
  
  def start_response(response)
    builder.response_line response[0]
    response[1][STR_SERVER] ||= STR_VERSION
    builder.headers response[1]
  end
  
  def close_response(request)
    builder.complete
    requests.delete(request).succeed
  end
    
  def inject_environment(env)
    env[STR_HATETEPE_CONNECTION] = self
    env[STR_RACK_URL_SCHEME] = "http"
    env[STR_RACK_INPUT].source = self
    env[STR_RACK_ERRORS] = errors
    
    env[STR_RACK_MULTITHREAD] = false
    env[STR_RACK_MULTIPROCESS] = false
    env[STR_RACK_RUN_ONCE] = false
    
    env[STR_SERVER_NAME] = config[:host].dup
    env[STR_SERVER_PORT] = String(config[:port])
    env[STR_REMOTE_ADDR] = remote_address.dup
    env[STR_REMOTE_PORT] = String(remote_port)
    
    host = env[STR_HTTP_HOST] || config[:host].dup
    host += ":#{config[:port]}" unless host.include? ":"
    env[STR_HTTP_HOST] = host
  end
end

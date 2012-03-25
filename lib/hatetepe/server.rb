require "eventmachine"
require "em-synchrony"
require "rack"

require "hatetepe/builder"
require "hatetepe/connection"
require "hatetepe/parser"
require "hatetepe/version"

module Hatetepe::Server
  include Hatetepe::Connection

  attr_reader :config

  # @api public
  def self.start(config, &app)
    EM.start_server(config[:host], config[:port], self, config)
  end

  # @api semipublic
  def initialize(config)
    @config = config
  end

  # @api semipublic
  def post_init
    @parser, @builder = Hatetepe::Parser.new, Hatetepe::Builder.new
    @parser.on_request &method(:process_request)
    @builder.on_write  &method(:send_data)
    # @builder.on_write {|data| p "<--| #{data}" }
  end

  # @api semipubic
  def receive_data(data)
    # p "-->| #{data}"
    @parser << data
  end

  # @api private
  def process_request(request)
    Fiber.new do
      env      = build_env(request)
      response = config[:app].call(env)
      send_response(response)
    end.resume
  end

  def build_env(request)
    request.to_h.merge({
      "SERVER_NAME"         => config[:host],
      "SERVER_PORT"         => config[:port].to_s,
      "rack.errors"         => $stderr,
      "rack.multithread"    => false,
      "rack.multiprocess"   => false,
      "rack.run_once"       => false,
      "rack.url_scheme"     => "http",
      "hatetepe.connection" => self
    })
  end

  # @api private
  def send_response(response)
    @builder.response(response.to_a)
  end

  # @api semipublic
  def unbind(reason)
  end

  # @api public
  def stop
  end

  # @api public
  def stop!
  end
end

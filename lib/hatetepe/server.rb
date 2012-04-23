require "eventmachine"
require "em-synchrony"

require "hatetepe/builder"
require "hatetepe/connection"
require "hatetepe/parser"
require "hatetepe/server/keep_alive"
require "hatetepe/server/pipeline"
require "hatetepe/server/rack_app"
require "hatetepe/version"

module Hatetepe::Server
  include Hatetepe::Connection

  attr_reader :config, :requests

  CONFIG_DEFAULTS = { :timeout => 5.0 }

  # @api public
  def self.start(config)
    EM.start_server(config[:host], config[:port], self, config)
  end

  # @api semipublic
  def initialize(config)
    @config = CONFIG_DEFAULTS.merge(config)
  end

  # @api semipublic
  def post_init
    @parser, @builder = Hatetepe::Parser.new, Hatetepe::Builder.new
    @parser.on_request &method(:process_request)
    @builder.on_write  &method(:send_data)
    # @builder.on_write {|data| p "<--| #{data}" }

    @app = [
      Pipeline,
      KeepAlive,
      RackApp
    ].reverse.inject(config[:app]) {|inner, outer| outer.new(inner, self) }

    self.comm_inactivity_timeout = config[:timeout]
  end

  # @api semipubic
  def receive_data(data)
    # p "-->| #{data}"
    @parser << data
  rescue Object => ex
    p ex
    close_connection
  end

  # @api private
  def process_request(request)
    Fiber.new do
      @app.call(request) do |response|
        send_response(request, response)
      end
    end.resume
  end

  # @api private
  def send_response(request, response)
    self.comm_inactivity_timeout = 0
    @builder.response(response.to_a)
    self.comm_inactivity_timeout = config[:timeout]

    if response.failure?
      request.fail(response)
    else
      request.succeed(response)
    end
  end

  # @api semipublic
  def unbind(reason)
    super
  end

  # @api public
  def stop
  end

  # @api public
  def stop!
    close_connection_after_writing
  end
end

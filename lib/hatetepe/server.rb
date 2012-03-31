require "eventmachine"
require "em-synchrony"
require "rack"

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

  CONFIG_DEFAULTS = { :timeout => 1 }

  # @api public
  def self.start(config, &app)
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

    @app = Rack::Builder.new.tap do |b|
      b.use Pipeline,  self
      b.use KeepAlive, self
      b.run RackApp.new(config[:app], self)
    end.to_app

    @requests = []
  end

  # @api semipubic
  def receive_data(data)
    # p "-->| #{data}"
    @parser << data
  end

  # @api private
  def process_request(request)
    Fiber.new do
      requests << request
      @app.call(request) do |response|
        send_response(request, response)
      end
    end.resume
  end

  # @api private
  def send_response(request, response)
    @builder.response(response.to_a)
    requests.delete(request)

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
  end
end

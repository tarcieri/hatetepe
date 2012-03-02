require "em-synchrony"
require "eventmachine"
require "rack"
require "uri"

require "hatetepe/builder"
require "hatetepe/connection"
require "hatetepe/parser"
require "hatetepe/request"
require "hatetepe/version"

module Hatetepe
  class Client < Connection
    Job = Struct.new(:fiber, :request, :sent, :response)

    CONFIG_DEFAULTS = {
      :host            => "127.0.0.1",
      :port            => 3000,
      :timeout         => 2,
      :connect_timeout => 2
    }

    attr_reader :config, :app

    # @api semipublic
    def initialize(config)
      @config = CONFIG_DEFAULTS.merge(config)
    end

    # @api semipublic
    def post_init
      @builder, @parser   =  Builder.new, Parser.new
      @builder.on_write   << method(:send_data)
      # @builder.on_write {|data| p "--> #{data}" }
      @parser.on_response << method(:receive_response)

      @queue = []

      @app = method(:send_request)
    end

    # @api semipublic
    def receive_data(data)
      # p "<-- #{data}"
      @parser << data
    end

    # @api semipublic
    def unbind
      super
      @queue.each {|job| job.fiber.resume(:kill) }
    end

    # @api public
    def <<(request)
      Fiber.new do
        response = @app.call(request)

        if !response || response.failure?
          request.fail(response)
        else
          request.succeed(response)
        end
      end.resume
    end

    # @return [Hatetepe::Response, nil]
    #
    # @api public
    def request(verb, uri, headers = {}, body = [])
      request =  Request.new(verb, uri, headers, body)
      self    << request
      EM::Synchrony.sync(request)
    end

    # @api public
    def stop
      wait
      stop!
    end

    # @api public
    def stop!
      close_connection
    end

    # @api public
    def wait
      if job = @queue.last
        EM::Synchrony.sync(job.request)
        EM::Synchrony.sync(job.response.body) if job.response
      end
    end

    # @api public
    def self.start(config)
      EM.connect(config[:host], config[:port], self, config)
    end

    # @api public
    def self.request(verb, uri, headers = {}, body = [])
    end

    # @return [Hatetepe::Response, nil]
    #
    # @api private
    def send_request(request)
      previous =  @queue.last
      current  =  Job.new(Fiber.current, request, false)
      @queue   << current

      # wait for the previous request to be sent
      while previous && !previous.sent
        return if Fiber.yield == :kill
      end

      # send the request
      @builder.request(request.to_a)
      current.sent = true

      # wait for the response
      while !current.response
        return if Fiber.yield == :kill
      end

      # clean up and return response
      @queue.delete(current)
      current.response
    end

    # @api private
    def receive_response(response)
      job = @queue.find {|j| j.response.nil? }
      unless job
        raise "Received response without expecting one: #{response.status}"
      end

      job.response = response
      job.fiber.resume
    end
  end
end

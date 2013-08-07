require "em-synchrony"
require "eventmachine"

require "hatetepe/builder"
require "hatetepe/connection"
require "hatetepe/parser"
require "hatetepe/request"
require "hatetepe/version"

module Hatetepe
  HatetepeError = Class.new(StandardError)
  RequestError  = Class.new(HatetepeError)
  ClientError   = Class.new(RequestError)
  ServerError   = Class.new(RequestError)
end

module Hatetepe::Client
  include Hatetepe::Connection

  # @api private
  Job = Struct.new(:fiber, :request, :sent, :response)

  # The default configuration.
  #
  # @api public
  CONFIG_DEFAULTS = {
    :timeout         => 5,
    :connect_timeout => 5
  }

  # The configuration for this Client instance.
  #
  # @api public
  attr_reader :config

  # The pipe of middleware and request transmission/response reception.
  #
  # @api private
  attr_reader :app

  # Initializes a new Client instance.
  #
  # @param [Hash] config
  #   Configuration values that overwrite the defaults.
  #
  # @api semipublic
  def initialize(config)
    @config = CONFIG_DEFAULTS.merge(config)
    @ssl_handshake_completed = EM::DefaultDeferrable.new
  end

  # Initializes the parser, request queue, and middleware pipe.
  #
  # @see EM::Connection#post_init
  #
  # @api semipublic
  def post_init
    @builder, @parser   =  Hatetepe::Builder.new, Hatetepe::Parser.new
    @builder.on_write   << method(:send_data)
    # @builder.on_write {|data| p "|--> #{data}" }
    @parser.on_response << method(:receive_response)

    @queue = []

    @app = proc {|request| send_request(request) }

    self.comm_inactivity_timeout = config[:timeout]
    self.pending_connect_timeout = config[:connect_timeout]

    start_tls if config[:ssl]
  end

  def ssl_handshake_completed
    EM::Synchrony.next_tick { @ssl_handshake_completed.succeed }
  end

  # Feeds response data into the parser.
  #
  # @see EM::Connection#receive_data
  #
  # @param [String] data
  #   The received data that's gonna be fed into the parser.
  #
  # @api semipublic
  def receive_data(data)
    # p "|<-- #{data}"
    @parser << data
  end

  # Aborts all outstanding requests.
  #
  # @see EM::Connection#unbind
  #
  # @api semipublic
  def unbind(reason)
    super
    @queue.each {|job| job.fiber.resume(:kill) }
  end

  # Sends a request and waits for the response without blocking.
  #
  # Transmission and reception are performed within a separate +Fiber+.
  # +#succeed+ and +#fail+ will be called on the +request+ passing the
  # response, depending on whether the response indicates success (100-399)
  # or failure (400-599).
  #
  # The request will +#fail+ with a +nil+ response if the connection was
  # closed for whatever reason.
  #
  # TODO find out if there are more cases where the response body
  #      should automatically be closed.
  #
  # @api public
  def <<(request)
    Fiber.new do
      EM::Synchrony.sync(@ssl_handshake_completed) if config[:ssl]

      response = @app.call(request)

      if response && (request.verb == "HEAD" || response.status == 204)
        response.body.close_write
      end

      if !response
        request.fail
      elsif response.failure?
        request.fail(response)
      else
        request.succeed(response)
      end
    end.resume
  end

  # Builds a +Request+, sends it, and blocks while waiting for the response.
  #
  # @param [Symbol, String] verb
  #   The HTTP method verb, e.g. +:get+ or +"PUT"+.
  # @param [String, URI]    uri
  #   The request URI.
  # @param [Hash]           headers (optional)
  #   The request headers.
  # @param [#each]          body    (optional)
  #   A request body object whose +#each+ method yields objects that respond
  #   to +#to_s+.
  #
  # @return [Hatetepe::Response, nil]
  #
  # @api public
  def request(verb, uri, headers = {}, body = [])
    uri = URI(uri)
    uri.scheme ||= @config[:ssl] ? 'http' : 'https'
    uri.host ||= @config[:host]
    uri.port ||= @config[:port]

    headers['Host'] ||= "#{uri.host}:#{uri.port}"

    request =  Hatetepe::Request.new(verb, URI(uri.to_s), headers, body)
    self    << request
    EM::Synchrony.sync(request)
  end

  # Like +#request+, but raises errors for 4xx and 5xx responses.
  #
  # @param [Symbol, String] verb
  #   The HTTP method verb, e.g. +:get+ or +"PUT"+.
  # @param [String, URI]    uri
  #   The request URI.
  # @param [Hash]           headers (optional)
  #   The request headers.
  # @param [#each]          body    (optional)
  #   A request body object whose +#each+ method yields objects that respond
  #   to +#to_s+.
  #
  # @return [Hatetepe]::Response, nil]
  #
  # @raise [Hatetepe::ClientError]
  #   If the server responded with a 4xx status code.
  # @raise [Hatetepe::ServerError]
  #   If the server responded with a 5xx status code.
  # @raise [Hatetepe::RequestError]
  #   If the client failed to receive any response at all.
  def request!(verb, uri, headers = {}, body = [])
    response = request(verb, uri, headers, body)

    if response.nil?
      raise Hatetepe::RequestError
    elsif response.status >= 500
      raise Hatetepe::ServerError
    elsif response.status >= 400
      raise Hatetepe::ClientError
    end

    response
  end

  # Gracefully stops the client.
  #
  # Waits for all requests to finish and then stops the client.
  #
  # @api public
  def stop
    wait
    stop!
  end

  # Immediately stops the client by closing the connection.
  #
  # This will lead to EventMachine's event loop calling {#unbind}, which fail
  # all outstanding requests.
  #
  # @see #unbind
  #
  # @api public
  def stop!
    close_connection
  end

  # Blocks until the last request has finished receiving its response.
  #
  # Returns immediately if there are no outstanding requests.
  #
  # @api public
  def wait
    if job = @queue.last
      EM::Synchrony.sync(job.request)
      EM::Synchrony.sync(job.response.body) if job.response
    end
  end

  # Starts a new Client.
  #
  # @param [Hash] config
  #   The +:host+ and +:port+ the Client should connect to.
  #
  # @return [Hatetepe::Client]
  #   The new Client instance.
  #
  # @api public
  def self.start(config)
    EM.connect(config[:host], config[:port], self, config)
  end

  # @api public
  def self.request(verb, uri, headers = {}, body = [])
    uri    = URI(uri)
    client = start(host: uri.host, port: uri.port, ssl: uri.scheme == 'https')
    client.request(verb, uri, headers, body)
  end

  # Feeds the request into the builder and blocks while waiting for the
  # response to arrive.
  #
  # Supports the request bit of HTTP pipelining by waiting until the previous
  # request has been sent.
  #
  # @param [Hatetepe::Request] request
  #   The request that's gonna be sent.
  #
  # @return [Hatetepe::Response, nil]
  #   The received response or +nil+ if the connection has been closed before
  #   receiving a response.
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
    self.comm_inactivity_timeout = 0
    @builder.request(request.to_a)
    current.sent = true
    self.comm_inactivity_timeout = config[:timeout]

    # wait for the response
    while !current.response
      return if Fiber.yield == :kill
    end

    # clean up and return response
    @queue.delete(current)
    current.response
  end

  # Relates an incoming response to the corresponding request.
  #
  # Supports the response bit of HTTP pipelining by relating responses to
  # requests in the order the requests were sent.
  #
  # TODO: raise a more meaningful error.
  #
  # @param [Hatetepe::Response] response
  #   The incoming response
  #
  # @raise [RuntimeError]
  #   There is no request that's waiting for a response.
  #
  # @api private
  def receive_response(response)
    query = proc {|j| j.response.nil? }

    if job = @queue.find(&query)
      job.response = response
      job.fiber.resume
    else
      raise "Received response but didn't expect one: #{response.status}"
    end
  end

  module VerbMethods
    [
      :get, :head, :options, :put, :post, :delete, :patch, :connect
    ].each do |verb|
      define_method(verb) do |uri, headers = {}, body = []|
        request(verb, uri, headers, body)
      end
    end
  end

  include VerbMethods
  extend VerbMethods
end

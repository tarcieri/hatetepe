require "em-synchrony"
require "eventmachine"
require "rack"
require "uri"

require "hatetepe/builder"
require "hatetepe/connection"
require "hatetepe/deferred_status_fix"
require "hatetepe/parser"
require "hatetepe/request"
require "hatetepe/version"

module Hatetepe
  class Client < Hatetepe::Connection; end
end

require "hatetepe/client/keep_alive"
require "hatetepe/client/pipeline"

class Hatetepe::Client
  attr_reader :app, :config
  attr_reader :parser, :builder
  attr_reader :requests, :pending_transmission, :pending_response
  
  def initialize(config)
    @config = config
    @parser,  @builder = Hatetepe::Parser.new, Hatetepe::Builder.new
    
    @requests = []
    @pending_transmission, @pending_response = {}, {}
    
    @app = Rack::Builder.new.tap do |b|
      b.use KeepAlive
      b.use Pipeline
      b.run method(:send_request)
    end.to_app
    
    super
  end
  
  def post_init
    parser.on_response << method(:receive_response)
    # XXX check if the connection is still present
    builder.on_write << method(:send_data)
    #builder.on_write {|data| p "client >> #{data}" }
    
    self.processing_enabled = true
  end
  
  def receive_data(data)
    #p "client << #{data}"
    parser << data
  rescue => e
    close_connection
    raise e
  end
  
  def send_request(request)
    id = request.object_id
    
    request.headers.delete "X-Hatetepe-Single"
    builder.request request.to_a
    pending_transmission[id].succeed
    
    pending_response[id] = EM::DefaultDeferrable.new
    EM::Synchrony.sync pending_response[id]
  ensure
    pending_response.delete id
  end
  
  def receive_response(response)
    requests.find {|req| !req.response }.tap do |req|
      req.response = response
      pending_response[req.object_id].succeed response
    end
  end
  
  def <<(request)
    request.connection = self
    unless processing_enabled?
      request.fail
      return
    end
    
    requests << request
    
    Fiber.new do
      begin
        pending_transmission[request.object_id] = EM::DefaultDeferrable.new
        
        app.call(request).tap do |response|
          request.response = response
          # XXX check for response.nil?
          status = (response && response.success?) ? :succeed : :fail
          requests.delete(request).send status, response
        end
      ensure
        pending_transmission.delete request.object_id
      end
    end.resume
  end
  
  def request(verb, uri, headers = {}, body = nil, http_version = "1.1")
    headers["Host"] ||= "#{config[:host]}:#{config[:port]}"
    headers["User-Agent"] ||= "hatetepe/#{Hatetepe::VERSION}"
    
    body = wrap_body(body)
    if headers["Content-Type"] == "application/x-www-form-urlencoded"
      enum = Enumerator.new(body)
      headers["Content-Length"] = enum.inject(0) {|a, e| a + e.length }
    end
    
    request = Hatetepe::Request.new(verb, uri, headers, body, http_version)
    self << request
    self.processing_enabled = false
    EM::Synchrony.sync request
    
    request.response.body.close_write if request.verb == "HEAD"
    
    request.response
  end
  
  def stop
    unless requests.empty?
      last_response = EM::Synchrony.sync(requests.last)
      EM::Synchrony.sync last_response.body if last_response.body
    end
    close_connection
  end
  
  def unbind
    super
    
    EM.next_tick do
      requests.each do |req|
        # fail state triggers
        req.object_id.tap do |id|
          pending_transmission[id].fail if pending_transmission[id]
          pending_response[id].fail if pending_response[id]
        end
        # fail reponse body if the response has already been started
        if req.response
          req.response.body.tap {|b| b.close_write unless b.closed_write? }
        end
        # XXX FiberError: dead fiber called because req already succeeded
        #     or failed, see github.com/eventmachine/eventmachine/issues/287
        req.fail req.response
      end
    end
  end
  
  def wrap_body(body)
    if body.respond_to? :each
      body
    elsif body.respond_to? :read
      [body.read]
    elsif body
      [body]
    else
      []
    end
  end
  
  class << self
    def start(config)
      EM.connect config[:host], config[:port], self, config
    end
    
    def request(verb, uri, headers = {}, body = nil)
      uri = URI(uri)
      client = start(:host => uri.host, :port => uri.port)
      
      headers["X-Hatetepe-Single"] = true
      client.request(verb, uri.request_uri, headers, body).tap do |*|
        client.stop
      end
    end
  end
  
  [self, self.singleton_class].each do |cls|
    [:get, :head, :post, :put, :delete,
     :options, :trace, :connect].each do |verb|
      cls.send(:define_method, verb) {|uri, *args| request verb, uri, *args }
    end
  end
end

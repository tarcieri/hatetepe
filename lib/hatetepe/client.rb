require "em-synchrony"
require "eventmachine"
require "rack"
require "uri"

require "hatetepe/builder"
require "hatetepe/parser"
require "hatetepe/request"
require "hatetepe/version"

module Hatetepe
  class Client < EM::Connection; end
end

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
      b.use Pipeline
      b.run method(:send_request)
    end.to_app
    
    super
  end
  
  def post_init
    parser.on_response << method(:receive_response)
    builder.on_write << method(:send_data)
    #builder.on_write {|data| p "--> #{data}" }
  end
  
  def receive_data(data)
    #p "<-- #{data}"
    parser << data
  rescue => e
    stop!
    raise e
  end
  
  def send_request(request)
    id = request.object_id
    
    builder.request request.to_a
    pending_transmission[id].succeed
    
    pending_response[id] = EM::DefaultDeferrable.new
    EM::Synchrony.sync pending_response[id]
  ensure
    pending_response.delete id
  end
  
  def receive_response(response)
    id = requests.find {|req| !req.response }.object_id
    pending_response[id].succeed response
  end
  
  def <<(request)
    Fiber.new do
      request.connection = self
      requests << request
      begin
        pending_transmission[request.object_id] = EM::DefaultDeferrable.new
        
        app.call(request).tap do |response|
          request.response = response
          request.send (response.success? ? :succeed : :fail), response
        end
      ensure
        pending_transmission.delete request.object_id
      end
    end.resume
  end
  
  def request(verb, uri, headers = {}, body = nil)
    headers["Host"] ||= "#{config[:host]}:#{config[:port]}"
    headers["User-Agent"] ||= "hatetepe/#{Hatetepe::VERSION}"
    
    body = wrap_body(body)
    if headers["Content-Type"] == "application/x-www-form-urlencoded"
      headers["Content-Length"] = body.to_enum.inject(0) {|a, e| a + e.length }
    end
    
    request = Hatetepe::Request.new(verb, uri, headers, body)
    self << request
    EM::Synchrony.sync request
    
    request.response.body.close_write if request.verb == "HEAD"
    
    request.response
  end
  
  def stop
    unless requests.empty?
      last_response = EM::Synchrony.sync(requests.last)
      EM::Synchrony.sync last_response.body
    end
    stop!
  end
  
  def stop!
    close_connection
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
      uri = URI.parse(uri)
      client = start(:host => uri.host, :port => uri.port)
      
      client.request(verb, uri.request_uri, headers, body).tap do |response|
        response.body.callback { client.stop }
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

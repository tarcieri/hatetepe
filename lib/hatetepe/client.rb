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
  attr_reader :requests, :pending_requests, :pending_responses
  
  def initialize(config)
    @config = config
    @parser,  @builder = Hatetepe::Parser.new, Hatetepe::Builder.new
    
    @requests = []
    @pending_requests, @pending_responses = {}, {}
    
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
    pending_requests[id].succeed
    
    pending_responses[id] = EM::DefaultDeferrable.new
    EM::Synchrony.sync pending_responses[id]
  ensure
    pending_responses.delete id
  end
  
  def receive_response(response)
    id = requests.find {|req| !req.response }.object_id
    pending_responses[id].succeed response
  end
  
  def <<(request)
    Fiber.new do
      request.connection = self
      requests << request
      pending_requests[request.object_id] = EM::DefaultDeferrable.new
      
      request.response = app.call(request)
      request.succeed request.response
    end.resume
  end
  
  def request(verb, uri, headers = {}, body = nil)
    headers["User-Agent"] ||= "hatetepe/#{Hatetepe::VERSION}"
    
    request = Hatetepe::Request.new(verb, uri, headers, body)
    request.body.close_write unless body
    
    self << request
    EM::Synchrony.sync request
    request.response
  end
  
  def stop
    EM::Synchrony.sync requests.last unless requests.empty?
    stop!
  end
  
  def stop!
    close_connection
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
    [:get, :head, :post, :put, :delete].each do |verb|
      cls.send(:define_method, verb) {|uri, *args| request verb, uri, *args }
    end
  end
end

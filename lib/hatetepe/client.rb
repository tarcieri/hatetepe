require "em-synchrony"
require "eventmachine"
require "uri"

require "hatetepe/body"
require "hatetepe/builder"
require "hatetepe/parser"
require "hatetepe/request"
require "hatetepe/response"
require "hatetepe/version"

module Hatetepe
  class Client < EM::Connection
    def self.start(config)
      EM.connect config[:host], config[:port], self, config
    end
    
    def self.request(verb, uri, headers = {}, body = nil)
      uri = URI.parse(uri)
      client = start(:host => uri.host, :port => uri.port)
      
      headers["User-Agent"] ||= "hatetepe/#{VERSION}"
      
      Request.new(verb, uri.request_uri).tap do |req|
        req.headers = headers
        req.body = body || Body.new.tap {|b| b.close_write }
        client << req
        EM::Synchrony.sync req
      end.response
    end
    
    class << self
      [:get, :head].each do |verb|
        define_method verb do |uri, headers = {}|
          request verb.to_s.upcase, uri, headers
        end
      end
      [:options, :post, :put, :delete, :trace, :connect].each do |verb|
        define_method verb do |uri, headers = {}, body = nil|
          request verb.to_s.upcase, uri, headers, body
        end
      end
    end
    
    attr_reader :config
    attr_reader :requests, :parser, :builder
    
    def initialize(config)
      @config = config
      @requests = []
      @parser, @builder = Parser.new, Builder.new
      super
    end
    
    def post_init
      parser.on_response do |response|
        requests.find {|req| !req.response }.response = response
      end
      
      parser.on_headers do
        requests.reverse.find {|req| !!req.response }.tap do |req|
          req.response.body.source = self
          req.succeed req.response
        end
      end
      
      #builder.on_write {|chunk|
      # ap "-> #{chunk}"
      #}
      builder.on_write << method(:send_data)
    end
    
    def <<(request)
      request.headers["Host"] = "#{config[:host]}:#{config[:port]}"

      requests << request
      Fiber.new do
        builder.request_line request.verb, request.uri
        
        if request.headers["Content-Type"] == "application/x-www-form-urlencoded"
          if request.body.respond_to? :read
            request.headers["Content-Length"] = request.body.read.bytesize
          else
            request.headers["Content-Length"] = request.body.length
          end
        end
        builder.headers request.headers
        
        b = request.body
        if Body === b || b.respond_to?(:each)
          builder.body b
        elsif b.respond_to? :read
          builder.body [b.read]
        else
          builder.body [b]
        end
        
        builder.complete
      end.resume
    end
    
    def receive_data(data)
      #ap "<- #{data}"
      parser << data
    end
    
    def stop
      responses.last.body.sync
      close_connection_after_writing
    end
    
    def responses
      requests.map(&:response).compact
    end
  end
end

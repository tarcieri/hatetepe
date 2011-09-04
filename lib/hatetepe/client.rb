require "em-synchrony"
require "eventmachine"
require "uri"

require "hatetepe/body"
require "hatetepe/builder"
require "hatetepe/parser"
require "hatetepe/request"
require "hatetepe/response"

module Hatetepe
  class Client < EM::Connection
    def self.start(config)
      EM.connect config[:host], config[:port], self, config
    end
    
    def self.request(verb, uri, headers = {}, body = nil)
      uri = URI.parse(uri)
      client = start(:host => uri.host, :port => uri.port)
      
      headers["User-Agent"] ||= "hatetepe/#{VERSION}"
      
      EM::Synchrony.sync Request.new(verb, uri.request_uri).tap {|req|
        req.headers = headers
        req.body = body || Body.new.tap {|b| b.close_write }
        client << req
      }
    end
    
    class << self
      [:get, :head].each {|verb|
        define_method(verb) {|uri, headers = {}|
          request verb.to_s.upcase, uri, headers
        }
      }
      [:options, :post, :put, :delete, :trace, :connect].each {|verb|
        define_method(verb) {|uri, headers = {}, body = nil|
          request verb.to_s.upcase, uri, headers, body
        }
      }
    end
    
    attr_reader :config
    attr_reader :requests, :parser, :builder
    
    def initialize(config)
      @config = config
      super
    end
    
    def post_init
      @requests = []
      @parser, @builder = Parser.new, Builder.new
      
      parser.on_response {|response|
        requests.find {|req| !req.response }.response = response
      }
      parser.on_headers {
        requests.reverse.find {|req| !!req.response }.tap {|req|
          req.succeed req.response
        }
      }
      
      #builder.on_write {|chunk|
      # ap "-> #{chunk}"
      #}
      builder.on_write << method(:send_data)
    end
    
    def <<(request)
      builder.reset
      requests << request
      
      builder.request request.verb, request.uri
      request.headers.each_pair {|key, value| builder.header key, value }
      request.body.each &builder.method(:body) unless request.body.empty?
      builder.complete
    end
    
    def receive_data(data)
      #ap "<- #{data}"
      parser << data
    end
    
    def responses
      requests.map(&:response).compact
    end
  end
end

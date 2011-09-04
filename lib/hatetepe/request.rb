require "hatetepe/message"

module Hatetepe
  class Request < Message
    include EM::Deferrable
    
    attr_accessor :verb, :uri, :response
    
    def initialize(verb, uri, http_version = "1.1")
      @verb, @uri = verb, uri
      super http_version
    end
    
    def to_hash
      {
        "rack.version" => [1, 0],
        "hatetepe.request" => self,
        "rack.input" => body,
        "REQUEST_METHOD" => verb.dup,
        "REQUEST_URI" => uri.dup
      }.tap {|h|
        headers.each {|key, value|
          h["HTTP_#{key.upcase.gsub(/[^A-Z_]/, "_")}"] = value
        }
        
        h["REQUEST_PATH"], qm, h["QUERY_STRING"] = uri.partition("?")
        h["PATH_INFO"], h["SCRIPT_NAME"] = h["REQUEST_PATH"].dup, ""
      }
    end
  end
end

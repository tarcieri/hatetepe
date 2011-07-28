require "hatetepe/message"

module Hatetepe
  class Request < Message
    include EM::Deferrable
    
    attr_accessor :verb, :uri
    
    def initialize(verb, uri, http_version = "1.1")
      @verb, @uri = verb, uri
      super http_version
    end
    
    def to_hash
      {"hatetepe.request" => self}.tap {|hash|
        headers.each {|key, value|
          hash["HTTP_#{key.upcase.gsub(/[^A-Z_]/, "_")}"] = value
        }
      }
    end
  end
end

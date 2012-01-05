require "hatetepe/deferred_status_fix"
require "hatetepe/message"

module Hatetepe
  class Request < Message
    include EM::Deferrable
    
    attr_reader :verb
    attr_accessor :uri, :response
    
    def initialize(verb, uri, headers = {}, body = nil, http_version = "1.1")
      self.verb = verb
      @uri = uri
      super headers, body, http_version
    end
    
    def verb=(verb)
      @verb = verb.to_s.upcase
    end
    
    def to_a
      [verb, uri, headers, body, http_version]
    end
    
    def to_h
      {
        "rack.version" => [1, 0],
        "hatetepe.request" => self,
        "rack.input" => body,
        "REQUEST_METHOD" => verb.dup,
        "REQUEST_URI" => uri.dup
      }.tap do |hsh|
        headers.each do |key, value|
          key = key.upcase.gsub /[^A-Z]/, "_"
          key = "HTTP_#{key}" unless key =~ /^CONTENT_(TYPE|LENGTH)$/
          hsh[key] = value.dup
        end

        hsh["REQUEST_PATH"], qm, hsh["QUERY_STRING"] = uri.partition("?")
        hsh["PATH_INFO"], hsh["SCRIPT_NAME"] = hsh["REQUEST_PATH"].dup, ""
        
        hsh["HTTP_VERSION"] = "HTTP/#{http_version}"
      end
    end
  end
end

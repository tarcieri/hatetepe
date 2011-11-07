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
      }.tap do |hsh|
        headers.each do |key, value|
          key = key.upcase.gsub /[^A-Z]/, "_"
          key = "HTTP_#{key}" unless key =~ /^CONTENT_(TYPE|LENGTH)$/
          hsh[key] = value.dup
        end

        hsh["REQUEST_PATH"], qm, hsh["QUERY_STRING"] = uri.partition("?")
        hsh["PATH_INFO"], hsh["SCRIPT_NAME"] = hsh["REQUEST_PATH"].dup, ""
      end
    end
  end
end

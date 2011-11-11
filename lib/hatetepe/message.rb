require "hatetepe/body"

module Hatetepe
  class Message
    attr_accessor :http_version, :headers, :body
    attr_accessor :connection
    
    def initialize(headers = {}, body = nil, http_version = "1.1")
      @headers, @http_version = headers, http_version
      @body = body || Body.new
    end
  end
end

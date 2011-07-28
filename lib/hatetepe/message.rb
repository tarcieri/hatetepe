require "hatetepe/body"

module Hatetepe
  class Message
    attr_accessor :http_version, :headers, :body
    
    def initialize(http_version = "1.1")
      @http_version = http_version
      @headers = {}
      @body = Body.new
    end
  end
end

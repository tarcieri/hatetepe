require "hatetepe/message"

module Hatetepe
  class Response < Message
    attr_accessor :status
    
    def initialize(status, http_version = "1.1")
      @status = status
      super http_version
    end
  end
end

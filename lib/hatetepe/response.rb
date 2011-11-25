require "hatetepe/message"

module Hatetepe
  class Response < Message
    attr_accessor :status, :request
    
    def initialize(status, headers = {}, body = nil, http_version = "1.1")
      @status = status
      super headers, body, http_version
    end
    
    def success?
      status.between? 100, 399
    end
    
    def failure?
      status.between? 400, 599
    end
    
    def to_a
      [status, headers, body]
    end
    
    def [](idx)
      to_a[idx]
    end
  end
end

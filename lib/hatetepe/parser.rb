require "ffi/http/parser"

require "hatetepe/events"
require "hatetepe/request"
require "hatetepe/response"

module Hatetepe
  class ParserError < StandardError; end
  
  class Parser
    include Events
    
    event :reset
    event :request, :response
    event :headers, :body
    event :trailing_header, :trailing_headers_complete
    event :complete
    
    attr_reader :message
    
    def initialize(&block)
      @parser = FFI::HTTP::Parser.new.tap do |p|
        p.on_headers_complete = proc do
          version = p.http_version.join(".")
          if p.http_method
            @message = Request.new(p.http_method, p.request_url,
                                   p.headers, Body.new, version)
            event! :request, message
          else
            @message = Response.new(p.status_code, p.headers, Body.new, version)
            event! :response, message
          end
          
          event! :headers, message.headers
          event! :body, message.body
          nil
        end
        
        p.on_body = proc do |chunk|
          message.body.write chunk unless message.body.closed_write?
        end
        
        p.on_message_complete = method(:complete)
      end
      
      reset
      
      if block
        block.arity == 0 ? instance_eval(&block) : block.call(self)
      end
    end
    
    def reset
      @parser.reset!
      event! :reset
      @message = nil
    end
    
    def complete
      message.body.rewind!
      message.body.close_write unless message.body.closed_write?
      event! :complete
    end
    
    def <<(data)
      @parser << data
    rescue HTTP::Parser::Error => e
      raise Hatetepe::ParserError, e.message, e.backtrace
    end
  end
end

require "http/parser"

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
      initialize_parser
      reset

      if block
        block.arity == 0 ? instance_eval(&block) : block.call(self)
      end
    end

    def initialize_parser
      @parser = HTTP::Parser.new.tap do |p|
        p.on_headers_complete = proc do |headers|
          headers_complete(p) unless message
          nil
        end
        
        p.on_body             = method(:body)
        p.on_message_complete = method(:complete)
      end
    end
    
    def reset
      @parser.reset!
      event! :reset
      @message = nil
    end
    
    def <<(data)
      @parser << data
    rescue HTTP::Parser::Error => e
      raise Hatetepe::ParserError, e.message, e.backtrace
    end

    private

    def headers_complete(parser)
      args = [ parser.headers, Body.new, parser.http_version.join(".") ]
      if parser.http_method
        @message = Request.new(parser.http_method, parser.request_url, *args)
        event! :request, @message
      else
        @message = Response.new(parser.status_code, *args)
        event! :response, @message
      end

      event! :headers, message.headers
      event! :body, message.body
    end

    def body(chunk)
      message.body.write chunk unless message.body.closed_write?
    end

    def complete
      message.body.rewind!
      message.body.close_write unless message.body.closed_write?
      event! :complete
      reset
    end
  end
end

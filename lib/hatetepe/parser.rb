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
      @parser = HTTP::Parser.new.tap {|p|
        p.on_headers_complete = proc {
          version = p.http_version.join(".")
          if p.http_method
            @message = Request.new(p.http_method, p.request_url, version)
            event! :request, message
          else
            @message = Response.new(p.status_code, version)
            event! :response, message
          end
          
          message.headers = p.headers
          event! :headers, message.headers
          
          event! :body, message.body
          nil
        }
        
        p.on_body = proc {|chunk|
          message.body << chunk unless message.body.closed_write?
        }
        
        p.on_message_complete = proc {
          message.body.close_write unless message.body.closed_write?
          event! :complete
        }
      }
      
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
    
    def <<(data)
      @parser << data
    rescue HTTP::Parser::Error => e
      raise Hatetepe::ParserError, e.message, e.backtrace
    end
  end
end

require "http/parser"

module Hatetepe
  class ParserError < StandardError; end
  
  class Parser
    def self.parse(data = [], &block)
      message = {}
      parser = new do |p|
        p.on_request do |*args|
          message[:http_method] = args[0]
          message[:request_url] = args[1]
          message[:http_version] = args[2]
        end
        p.on_response do |*args|
          message[:status] = args[0]
          message[:http_version] = args[1]
        end
        p.on_header do |name, value|
          (message[:headers] ||= {})[name] = value
        end
        p.on_body_chunk do |chunk|
          (message[:body] ||= "") << chunk
        end
      end
      
      if block
        block.arity == 0 ? parser.instance_eval(&block) : block.call(parser)
      end
      
      Array(data).each {|chunk| parser << chunk }
      message
    end
    
    def initialize(&block)
      @on_request, @on_response = [], []
      @on_header, @on_headers_complete = [], []
      @on_body_chunk, @on_complete, @on_error = [], [], []
      @parser = HTTP::Parser.new
      
      @parser.on_headers_complete = proc do
        if @parser.http_method
          on_request.each do |r|
            r.call(@parser.http_method, @parser.request_url, @parser.http_version.join("."))
          end
        else
          on_response.each do |r|
            r.call(@parser.status_code, @parser.http_version.join("."))
          end
        end
        
        @parser.headers.each do |header|
          on_header.each {|h| h.call(*header) }
        end
        
        on_headers_complete.each {|hc| hc.call }
      end
      
      @parser.on_body = proc do |chunk|
        on_body_chunk.each {|b| b.call(chunk) }
      end
      
      @parser.on_message_complete = proc do
        on_complete.each {|f| f.call }
      end
      
      reset
      
      if block
        block.arity == 0 ? instance_eval(&block) : block.call(self)
      end
    end
    
    def reset
      @parser.reset!
    end
    
    [:request, :response, :header, :headers_complete,
     :body_chunk, :complete, :error].each do |hook|
      define_method :"on_#{hook}" do |&block|
        store = instance_variable_get(:"@on_#{hook}")
        return store unless block
        store << block
      end
    end
    
    def <<(data)
      @parser << data
    rescue HTTP::Parser::Error => original_error
      error = ParserError.new(original_error.message)
      error.set_backtrace(original_error.backtrace)
      unless on_error.empty?
        on_error.each {|e| e.call(error) }
      else
        raise(error)
      end
    end
  end
end

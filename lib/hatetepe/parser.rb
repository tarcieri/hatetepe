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
    
    attr_reader :bytes_read
    
    def initialize(&block)
      @on_request, @on_response, @on_header = [], [], []
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
      end
      
      @parser.on_body = proc do |chunk|
        on_body_chunk.each {|b| b.call(chunk) }
      end
      
      @parser.on_message_complete = proc do
        on_complete.each {|f| f.call(bytes_read) }
      end
      
      reset
      
      if block
        block.arity == 0 ? instance_eval(&block) : block.call(self)
      end
    end
    
    def reset
      @parser.reset!
      @bytes_read = 0
    end
    
    [:request, :response, :header, :body_chunk, :complete, :error].each do |hook|
      define_method :"on_#{hook}" do |&block|
        store = instance_variable_get(:"@on_#{hook}")
        return store unless block
        store << block
      end
    end
    
    def <<(data)
      @bytes_read += data.length
      @parser << data
    rescue HTTP::Parser::Error => original_error
      error = ParserError.new(original_error.message)
      error.set_backtrace(original_error.backtrace)
      on_error.each {|e| e.call(error) }
      raise(error)
    end
  end
end

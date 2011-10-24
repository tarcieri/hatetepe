require "hatetepe/status"

module Hatetepe
  class BuilderError < StandardError; end
  
  class Builder
    def self.build(&block)
      message = ""
      builder = new do |b|
        b.on_write {|data| message << data }
      end
      
      block.arity == 0 ? builder.instance_eval(&block) : block.call(builder)
      
      builder.complete
      return message.empty? ? nil : message
    end
    
    attr_reader :state
    
    def initialize(&block)
      reset
      @on_write, @on_complete, @on_error = [], [], []
      
      if block
        block.arity == 0 ? instance_eval(&block) : block.call(self)
      end
    end
    
    def reset
      @state = :ready
      @chunked = nil
    end
    
    [:write, :complete, :error].each do |hook|
      define_method :"on_#{hook}" do |&block|
        store = instance_variable_get(:"@on_#{hook}")
        return store unless block
        store << block
      end
    end
    
    def ready?
      state == :ready
    end
    
    def writing_headers?
      state == :writing_headers
    end
    
    def writing_body?
      state == :writing_body
    end
    
    def writing_trailing_headers?
      state == :writing_trailing_headers
    end
    
    def chunked?
      @chunked
    end
    
    def request(req)
      request_line req[0], req[1]
      headers req[2]
      body req[3] if req[3]
      complete
    end
    
    def request_line(verb, uri, version = "1.1")
      complete unless ready?
      write "#{verb.upcase} #{uri} HTTP/#{version}\r\n"
      @state = :writing_headers
    end
    
    def response(res)
      response_line res[0]
      headers res[1]
      body res[2] if res[2]
      complete
    end
    
    def response_line(code, version = "1.1")
      complete unless ready?
      unless status = STATUS_CODES[code]
        error "Unknown status code: #{code}"
      end
      
      write "HTTP/#{version} #{code} #{status}\r\n"
      @state = :writing_headers
    end
    
    def header(name, value)
      raw_header "#{name}: #{value}"
    end
    
    def headers(hash)
      hash.each {|k, v| header k, v }
    end
    
    def raw_header(header)
      if ready?
        error "A request or response line is required before writing headers"
      elsif writing_body?
        error "Trailing headers require chunked transfer encoding" unless chunked?
        write "0\r\n"
        @state = :writing_trailing_headers
      end
      
      if @chunked.nil? && header[0..13] == "Content-Length"
        @chunked = false
      elsif @chunked.nil? && header[0..16] == "Transfer-Encoding"
        @chunked = true
      end
      
      write "#{header}\r\n"
    end
    
    def body(body)
      body.each {|c| body_chunk c }
      # XXX complete here?
    end
    
    def body_chunk(chunk)
      if ready?
        error "A request or response line and headers are required before writing body"
      elsif writing_trailing_headers?
        error "Cannot write body after trailing headers"
      elsif writing_headers?
        if @chunked.nil?
          header "Transfer-Encoding", "chunked"
        end
        write "\r\n"
        @state = :writing_body
      end
      
      if chunked?
        write "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n"
      else
        write chunk unless chunk.empty?
      end
    end
    
    def complete
      if ready?
        return
      elsif writing_headers? && @chunked.nil?
        header "Content-Length", "0"
      end
      body_chunk ""

      on_complete.each {|blk| blk.call }
      reset
    end
    
    def write(data)
      on_write.each {|blk| blk.call data }
    end
    
    def error(message)
      exception = BuilderError.new(message)
      unless on_error.empty?
        on_error.each {|blk| blk.call(exception) }
      else
        raise(exception)
      end
    end
  end
end

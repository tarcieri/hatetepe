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
    
    attr_reader :state, :bytes_written
    
    def initialize(&block)
      reset
      @on_write, @on_complete, @on_error = [], [], []
      
      if block
        block.arity == 0 ? instance_eval(&block) : block.call(self)
      end
    end
    
    def reset
      @state = :ready
      @chunked = true
      @bytes_written = 0
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
    
    def request(verb, uri, version = "1.1")
      complete unless ready?
      write "#{verb.upcase} #{uri} HTTP/#{version}\r\n"
      @state = :writing_headers
    end
    
    def response(code, version = "1.1")
      complete unless ready?
      unless status = STATUS_CODES[code]
        error "Unknown status code: #{code}"
      end
      write "HTTP/#{version} #{code} #{status}\r\n"
      @state = :writing_headers
    end
    
    def header(name, value, charset = nil)
      charset = charset ? "; charset=#{charset}" : ""
      raw_header "#{name}: #{value}#{charset}"
    end
    
    def raw_header(header)
      if ready?
        error "A request or response line is required before writing headers"
      elsif writing_body?
        error "Trailing headers require chunked transfer encoding" unless chunked?
        write "0\r\n"
        @state = :writing_trailing_headers
      end
      
      if header[0..13] == "Content-Length"
        @chunked = false
      end
      
      write "#{header}\r\n"
    end
    
    def body(chunk)
      if ready?
        error "A request or response line and headers are required before writing body"
      elsif writing_trailing_headers?
        error "Cannot write body after trailing headers"
      elsif writing_headers?
        write "\r\n"
        @state = :writing_body
      end
      
      if chunked?
        write "#{chunk.length.to_s(16)}\r\n#{chunk}\r\n"
      else
        write chunk
      end
    end
    
    def complete
      return if ready?
      
      if writing_body? && chunked?
        write "0\r\n\r\n"
      elsif writing_headers? || writing_trailing_headers?
        write "\r\n"
      end
      
      on_complete.each {|blk| blk.call(bytes_written) }
      reset
    end
    
    def write(chunk)
      @bytes_written += chunk.length
      on_write.each {|blk| blk.call(chunk) }
    end
    
    def error(message)
      exception = BuilderError.new(message)
      exception.set_backtrace(caller[1..-1])
      on_error.each {|blk| blk.call(exception) }
      raise(exception)
    end
  end
end

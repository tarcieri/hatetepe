require "hatetepe/status"

module Hatetepe
  class BuilderError < StandardError; end
  
  METHODS = ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "PATCH", "CONNECT"]
  
  class Builder
    def self.build
      message = ""
      builder = new do |b|
        b.on_write {|chunk| message << chunk }
      end
      
      yield builder if block_given?
      message
    end
    
    attr_reader :status, :http_method, :request_url, :http_version, :headers, :body
    
    def initialize
      @on_write, @on_finish, @on_error = [], [], []
      
      reset
      
      yield self if block_given?
    end
    
    def reset
      @http_method, @status, @request_url = nil
      @http_version = "1.1"
      @headers = [], @body = []
    end
    
    [:write, :finish, :error].each do |hook|
      define_method :"on_#{hook}" do |&block|
        store = instance_variable_get(:"@on_#{hook}")
        return store unless block
        store << block
      end
    end
    
    def building?
      !!@building
    end
    
    def writing_body?
      !!@writing_body
    end
    
    def build
      return if building?
      
      @building = true
      if http_method && request_url
        write "#{http_method} #{request_url} #{http_version}\r\n"
      elsif status
        write "#{http_version} #{status} #{STATUS_CODES[status]}\r\n"
      else
        @building = false
        return
      end
      
      return if headers.empty?
      headers.each {|name, value| write_header(name, value) }
      
      @writing_body = true
      write "\r\n"
      return if body.empty?
      body.each {|chunk| write_body_chunk(chunk) }
      
      @building = false
      @writing_body = false
      on_finish.each {|f| f.call }
      
    rescue BuilderError => error
      on_error.each {|e| e.call(error) }
    end
    
    def finish
      unless writing_body?
        headers.each {|name| write_header(name, value) }
        write "\r\n"
        @writing_body = true
      end
      
      
      
      headers.each {|name, value| write_header(name, value) } unless writing_body?
      
    end
    
    def write(chunk)
      on_write.each {|w| w.call(chunk) }
    end
    
    def status=(status)
      status = Integer(status)
      raise BuilderError, "Unknown status: #{status}" unless STATUS_CODES[status]
      @status = status
      build
    end
    
    def http_method=(http_method)
      http_method = String(http_method).upcase
      raise BuilderError, "Unknown HTTP method: #{http_method}" unless METHODS.include?(http_method)
      @http_method = http_method
      build
    end
    
    def request_url=(request_url)
      @request_url = String(request_url)
      build
    end
    
    def http_version=(version)
      version = String(version)
      version.insert(0, "HTTP/") unless version =~ /^HTTP\//
      raise BuilderError, "Unknown HTTP version: #{version}" unless version =~ /^HTTP\/1\.(0|1)$/
      @http_version = version
      build
    end
    
    def headers=(headers)
      @headers = headers.respond_to?(:each) ? headers : Array(headers)
      build
    end
    
    def add_header(name, value)
      if building? && !writing_body?
        write_header(name, value)
      else
        headers[name] = value
      end
    end
    
    def write_header(name, value) # :nodoc:
      write "#{name}: #{value}\r\n"
    end
    
    def body=(body)
      @body = body.respond_to?(:each) ? body : Array(body)
      try_build
    end
    
    def add_body_chunk(chunk)
      if building? && writing_body?
        write_body_chunk(chunk)
      else
        body << chunk
      end
    end
    
    def write_body_chunk(chunk) # :nodoc:
      chunk = String(chunk)
      
      if headers["Transfer-Encoding"] && headers["Transfer-Encoding"] == "chunked"
        write "#{chunk.length.to_s(16)}\r\n#{chunk}\r\n"
      else
        write chunk
      end
    end
  end
end

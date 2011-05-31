require "hatetepe/status"

module Hatetepe
  class BuilderError < StandardError; end
  
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
    
    def try_build
      return if building?
      
      if http_method && request_url && http_version
        build
      elsif status && http_version
        build
      end
    end
    
    def building?
      !!@building
    end
    
    def build
      @building = true
    rescue BuilderError => error
      on_error.each {|e| e.call(error) }
      raise(error)
    end
    
    def write(chunk)
      on_write.each {|w| w.call(chunk) }
    end
    
    def status=(status)
      status = Integer(status)
      raise BuilderError, "Unknown HTTP status: #{status}" unless STATUS_CODES[status]
      @status = status
      try_build
    end
    
    def http_method=(http_method)
      @http_method = String(http_method)
      try_build
    end
    
    def request_url=(request_url)
      @request_url = String(request_url)
      try_build
    end
    
    def http_version=(version)
      @http_version = String(version)
      @http_version.insert(0, "HTTP/") unless @http_version =~ /^HTTP\//
      try_build
    end
    
    def headers=(headers)
      @headers = headers.respond_to?(:each) ? headers : Array(headers)
      try_build
    end
    
    def add_header(name, value)
      if building?
        write_header(name, value)
      else
        headers[name] = value
      end
    end
    
    def write_header(name, value)
      write "#{name}: #{value}\r\n"
    end
    
    def body=(body)
      @body = body.respond_to?(:each) ? body : Array(body)
      try_build
    end
    
    def add_body_chunk(chunk)
      if building?
        write_body_chunk(chunk)
      else
        body << chunk
      end
    end
    
    def write_body_chunk(chunk)
      chunk = String(chunk)
      headers["Transfer-Encoding"] ||= "chunked" unless headers["Content-Length"]
      
      if headers["Transfer-Encoding"] == "chunked"
        write "#{chunk.length.to_s(16)}\r\n#{chunk}\r\n"
      else
        write chunk
      end
    end
  end
end

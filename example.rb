require "hatetepe"

parser = Hatetepe::Parser.new do |p|
  p.on_request do |http_method, request_url, http_version|; end
  p.on_response do |status, http_version|; end
  p.on_header do |name, value|; end
  p.on_body_chunk do |chunk|; end
  p.on_error do |exception|; end
  p.on_finish do; end
  
  p << "GET / HTTP/1.1\r\n\r\n"
end

Hatetepe::Builder.new do |b|
  b.on_write do |chunk|
    $connection.write(chunk)
  end
  
  b.on_error {|e| @log.err e.message; raise(e) }
  
  b.on_finish { $connection.close }
  
  # build response
  b.status = 200
  b.headers = {"Content-Type" => "text/html"}
  b.http_version = "1.1"
  
  # append body
  b.body = "Foo Bar!"
  b.body = ["Hallo"]
  b.body << chunk
  b.body.close
  
  # build request
  b.request_url = "/asdf"
  b.headers = {}
  b.http_method = "PUT"
  b.http_version = "1.1"
  b.body << chunk
end

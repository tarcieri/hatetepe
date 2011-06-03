require "hatetepe"

parser = Hatetepe::Parser.new do |p|
  p.on_request do |http_method, request_url, http_version|; end
  p.on_response do |status, http_version|; end
  p.on_header do |name, value|; end
  p.on_body_chunk do |chunk|; end
  p.on_error do |exception|; end
  p.on_complete do; end
  
  p << "GET / HTTP/1.1\r\n\r\n"
end

Hatetepe::Builder.new do |b|
  b.on_write {|data| $connection.write(data) }
  b.on_error {|e| $log.err(e.message) }
  
  b.on_complete {|bytes_written| $connection.close }
  
  b.response 200
  b.header "Content-Type", "text/html", "utf-8"
  b.raw_header "Content-Length: 25"
  b.body "<p>Hallo Welt!</p>"
  
  b.response 201
  b.header "Location", "/new_entity"
  b.complete
end

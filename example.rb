require "hatetepe/parser"

parser = Hatetepe::Parser.new do |p|
  p.headers do |headers|; end
  p.body do |chunk|; end
  p.error do |exception|; end
  p.finish do; end
  
  p << "GET / HTTP/1.1\r\n\r\n"
end

Hatetepe::Builder.new do |b|
  b.write do |chunk|
    $connection.write(chunk)
  end
  
  b.error {|e| @log.err e.message; raise(e) }
  
  b.finish { $connection.close }
  
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

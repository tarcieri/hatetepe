require "bundler"
Bundler.setup

require "hatetepe"
require "awesome_print"

Hatetepe::Parser.parse do
  [:request, :response, :header, :body_chunk, :complete, :error].each do |hook|
    send :"on_#{hook}" do |*args|
      puts "on_#{hook}: #{args.inspect}"
    end
  end
  
  self << "HTTP/1.1 200 OK\r\nContent-Length: 11\r\n\r\nHallo Welt!"
end

Hatetepe::Builder.build do
  on_write {|data| p data }
  on_complete {|bytes_written| puts "Wrote #{bytes_written} bytes" }

  response 200
  header "Content-Type", "text/html", "utf-8"
  raw_header "Content-Length: 25"
  body "<p>Hallo Welt!</p>"
  
  response 201
  header "Location", "/new_entity"
  complete
end

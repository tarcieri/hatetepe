require "hatetepe/version"

module Hatetepe::Strings
  [
    "RACK_ENV",
    "testing",
    "stream.start",
    "stream.send",
    "stream.close",
    "Server",
    "hatetepe.connection",
    "rack.url_scheme",
    "rack.input",
    "rack.errors",
    "rack.multithread",
    "rack.multiprocess",
    "rack.run_once",
    "SERVER_NAME",
    "SERVER_PORT",
    "REMOTE_ADDR",
    "REMOTE_PORT",
    "HTTP_HOST"
  ].each do |str|
    const = str.gsub(/[^a-z]/i, "_").upcase.to_sym
    const_set :"STR_#{const}", str.freeze
  end

  STR_VERSION = "hatetepe/#{Hatetepe::VERSION}".freeze
end

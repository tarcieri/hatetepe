require "eventmachine"
require "em-synchrony"
require "hatetepe/server"
require "rack"

module Rack
  module Handler
    class Hatetepe
      def self.run(app, options = {})
        options = {
          :host => options[:Host] || "0.0.0.0",
          :port => options[:Port] || 8080,
          :app => app
        }
        
        Signal.trap("INT") { EM.stop }
        Signal.trap("TERM") { EM.stop }
        
        EM.epoll
        EM.synchrony { ::Hatetepe::Server.start options }
      end

      def self.valid_options
        {
          "Host=HOST" => "Hostname to listen on (default: 0.0.0.0 / all interfaces)",
          "Port=PORT" => "Port to listen on (default: 8080)",
        }
      end
    end
    
    register "hatetepe", Rack::Handler::Hatetepe
  end
end

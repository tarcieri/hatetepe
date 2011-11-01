require "eventmachine"
require "hatetepe/server"

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
        EM.synchrony do
          server = ::Hatetepe::Server.start options
          yield server if block_given?
        end
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

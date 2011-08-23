require "thor"

require "hatetepe"

module Hatetepe
  class CLI < Thor
    map "--version" => :version
    map "-v" => :version
    
    default_task :start
    
    desc :version, "Print version information"
    def version
      say Rity::VERSION
    end
    
    desc :start, "Start an instance of Rity"
    method_option :bind, :aliases => "-b", :type => :string,
      :banner => "Bind to the specified TCP interface (default: 127.0.0.1)"
    method_option :port, :aliases => "-p", :type => :numeric,
      :banner => "Bind to the specified port (default: 3000)"
    method_option :rackup, :aliases => "-r", :type => :string,
      :banner => "Load specified rackup (.ru) file (default: config.ru)"
    def start
      rackup = options[:rackup] || "config.ru"
      $stderr << "Booting from #{File.expand_path rackup}\n"
      $stderr.flush
      app = Rack::Builder.parse_file(rackup)[0]

      EM.synchrony do
        trap("INT") { EM.stop }
        trap("TERM") { EM.stop }
        
        EM.epoll
        
        host = options[:bind] || "127.0.0.1"
        port = options[:port] || 3000
        
        $stderr << "Binding to #{host}:#{port}\n"
        $stderr.flush
        Server.start({
          :app => app,
          :errors => $stderr,
          :host => host,
          :port => port
        })
      end
    end
  end
end

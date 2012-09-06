require "thor"

module Hatetepe
  class CLI < Thor
    map "--version" => :version
    map "-v" => :version
    
    default_task :start
    
    desc :version, "Print version information"
    def version
      require "hatetepe/version"
      say Hatetepe::VERSION
    end
    
    desc "[start]", "Start a server"
    method_option :bind, :aliases => "-b", :type => :string,
      :banner => "Bind to the specified TCP interface (default: 127.0.0.1)"
    method_option :port, :aliases => "-p", :type => :numeric,
      :banner => "Bind to the specified port (default: 3000)"
    method_option :rackup, :aliases => "-r", :type => :string,
      :banner => "Load specified rackup (.ru) file (default: config.ru)"
    method_option :env, :aliases => "-e", :type => :string,
      :banner => "Boot the app in the specified environment (default: development)"
    method_option :timeout, :aliases => "-t", :type => :numeric,
      :banner => "Time out connections after the specified admount of seconds (default: see Hatetepe::Server::CONFIG_DEFAULTS)"
    def start
      require "hatetepe/server"
      require "rack"

      config          = config_for(options)
      ENV["RACK_ENV"] = config[:env]

      $stderr << "We're in #{config[:env]}\n"
      $stderr << "Booting from #{config[:rackup]}\n"

      EM.epoll
      EM.synchrony do
        $stderr << "Binding to #{config[:host]}:#{config[:port]}\n"

        trap("INT") { EM.stop }
        trap("TERM") { EM.stop }
        Server.start(config)
      end
    end

    private

    def config_for(options)
      rackup = File.expand_path(options[:rackup] || "config.ru")
      {
        env:     options[:env]  || ENV["RACK_ENV"] || "development",
        host:    options[:bind] || "127.0.0.1",
        port:    options[:port] || 3000,
        timeout: options[:timeout],
        app:     Rack::Builder.parse_file(rackup)[0],
        rackup:  rackup
      }
    end
  end
end

require "logger"
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
    method_option :quiet, :aliases => "-q", :type => :boolean,
      :banner => "Don't log"
    method_option :verbose, :aliases => "-V", :type => :boolean,
      :banner => "Log debugging data"
    def start
      log = Logger.new($stderr)
      started_at = Time.now - 0.001
      log.formatter = proc do |severity, time, progname, message|
        time -= started_at
        "[#{time.round 6}] #{message}\n"
      end
      
      log.level = if options[:verbose]
        Logger::DEBUG
      elsif options[:quiet]
        Logger::FATAL
      else
        Logger::INFO
      end
      
      rackup = options[:rackup] || "config.ru"
      log.info "booting from #{File.expand_path rackup}"
      app = Rack::Builder.parse_file(rackup)[0]

      EM.synchrony do
        trap("INT") { EM.stop }
        trap("TERM") { EM.stop }
        
        EM.epoll
        
        host = options[:bind] || "127.0.0.1"
        port = options[:port] || 3000
        
        log.info "binding to #{host}:#{port}"
        Server.start({
          :app => app,
          :log => log,
          :host => host,
          :port => port
        })
      end
    rescue StandardError => ex
      log.fatal ex.message
      log << ex.backtrace.map {|line| "  #{line}\n" }.join("")
      raise ex
    end
  end
end

module Hatetepe
  module Connection
    attr_accessor :processing_enabled
    alias_method :processing_enabled?, :processing_enabled

    def remote_address
      sockaddr && sockaddr[1]
    end
    
    def remote_port
      sockaddr && sockaddr[0]
    end
    
    def sockaddr
      @sockaddr ||= Socket.unpack_sockaddr_in(get_peername) rescue nil
    end

    def connection_completed
      @connected = true
    end

    def connected?
      defined?(@connected) && @connected
    end
    
    def closed?
      !!defined?(@closed_by)
    end
    
    def closed_by_remote?
      @closed_by == :remote
    end
    
    def closed_by_self?
      @closed_by == :self
    end

    def closed_by_timeout?
      connected? && @closed_by == :timeout
    end

    def closed_by_connect_timeout?
      !connected? && @closed_by == :timeout
    end
    
    def close_connection(after_writing = false)
      @closed_by = :self unless closed?
      super
    end
    
    def unbind(reason)
      unless closed?
        @closed_by = if reason == Errno::ETIMEDOUT
          :timeout
        else
          :remote
        end
      end
    end

    def comm_inactivity_timeout=(seconds)
      unless defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
        super
      end
    end

    def pending_connect_timeout=(seconds)
      unless defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
        super
      end
    end
  end
end

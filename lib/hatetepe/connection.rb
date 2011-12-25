require "eventmachine"

module Hatetepe
  class Connection < EM::Connection
    def remote_address
      sockaddr && sockaddr[1]
    end
    
    def remote_port
      sockaddr && sockaddr[0]
    end
    
    def sockaddr
      @sockaddr ||= Socket.unpack_sockaddr_in(get_peername) rescue nil
    end
    
    def closed?
      !!@closed_by
    end
    
    def closed_by_remote?
      @closed_by == :remote
    end
    
    def closed_by_self?
      closed? && !closed_by_remote?
    end
    
    def close_connection(after_writing = false)
      @closed_by = :self
      super after_writing
    end
    
    def unbind
      @closed_by = :remote unless closed?
    end
  end
end

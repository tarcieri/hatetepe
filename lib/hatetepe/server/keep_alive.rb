class Hatetepe::Server
  class KeepAlive
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      m = case env["HTTP_CONNECTION"].to_s.downcase
        when "close" then :close
        when "keep-alive" then :keep_alive
        else env["HTTP_VERSION"] =~ /^HTTP\/(0\.9|1\.0)$/ ? :close : :keep_alive
      end
      
      send :"call_and_#{m}", env
    end
    
    def call_and_close(env, response = nil)
      req, conn = extract_request(env), extract_connection(env)
      
      conn.processing_enabled = false
      req.callback &conn.method(:close_connection_after_writing)
      req.errback &conn.method(:close_connection_after_writing)
      
      if response
        response[1]["Connection"] = "close"
      else
        stream_start = env["stream.start"]
        env["stream.start"] = proc do |res|
          res[1]["Connection"] = "close"
          stream_start.call res
        end
      end
      
      response || app.call(env)
    end
    
    def call_and_keep_alive(env)
      stream_start = env["stream.start"]
      env["stream.start"] = proc do |res|
        if res[1]["Connection"] == "close"
          call_and_close env, res
        else
          res[1]["Connection"] = "keep-alive"
        end
        stream_start.call res
      end
      
      app.call env
    end
    
    def extract_request(env)
      env["hatetepe.request"] || raise("env[hatetepe.request] not set")
    end
    
    def extract_connection(env)
      env["hatetepe.connection"] || raise("env[hatetepe.connection] not set")
    end
  end
end

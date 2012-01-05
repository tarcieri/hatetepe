class Hatetepe::Client
  class KeepAlive
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    # XXX should we be explicit about Connection: keep-alive?
    #     i think it doesn't matter if we send it as we don't wait
    #     for the first response to see if we're talking to an HTTP/1.1
    #     server. we're sending more requests anyway.
    
    # priority
    # 1. if X-Hatetepe-Single then Connection header, Client#request closes
    # 2. if req.Connection == close then Connection header and close
    # 3. if res.Connection == close then close
    def call(request)
      req, conn = request, request.connection
      
      single = req.headers.delete("X-Hatetepe-Single")
      req.headers["Connection"] ||= if single
        "close"
      else
        "keep-alive"
      end
      close = req.headers["Connection"] == "close"
      
      # stop processing further requests as early as possible
      conn.processing_enabled = false if close
      
      app.call(request).tap do |response|
        if !single && response.headers["Connection"] == "close"
          conn.processing_enabled = false
        end
      end
    end
    
    def call(request)
      req, conn = request, request.connection
      
      single = req.headers.delete("X-Hatetepe-Single")
      req.headers["Connection"] = "close" if single
      
      req.headers["Connection"] ||= "keep-alive"
      close = req.headers["Connection"] == "close"
      
      conn.processing_enabled = false if close
      
      app.call(request).tap do |res|
        if !single && (close || res.headers["Connection"] == "close")
          conn.processing_enabled = false
          conn.stop
        end
      end
    end
  end
end

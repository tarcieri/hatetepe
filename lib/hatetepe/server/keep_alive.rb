module Hatetepe::Server
  class KeepAlive
    def initialize(app, connection)
      @app, @connection = app, connection
    end

    def call(request, &respond)
      @app.call(request) do |response|
        respond.call(response)
        maybe_close(request, response)
      end
    end

    def maybe_close(request, response)
      version = request.http_version.to_f
      header  = request.headers["Connection"] || response.headers["Connection"]

      if (version < 1.1 && header != "keep-alive") || header == "close"
        @connection.stop!
      end
    end
  end
end

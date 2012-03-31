module Hatetepe::Server
  class KeepAlive
    def initialize(app, connection)
      @app, @connection = app, connection
    end

    def call(request, &respond)
      @app.call(request, &respond)
    end
  end
end

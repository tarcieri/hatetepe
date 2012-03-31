module Hatetepe::Server
  class RackApp
    def initialize(app, connection)
      @app, @connection = app, connection
    end

    def call(request, &respond)
      @respond = respond

      response = [ -1, {}, [] ]
      catch :async do
        response = @app.call(env_for(request))
      end

      respond(response)
    end

    def respond(response)
      if response[0] >= 0
        @respond.call(Hatetepe::Response.new(*response))
      end
    end

    def env_for(request)
      request.to_h.merge({
        "SERVER_NAME"         => @connection.config[:host],
        "SERVER_PORT"         => @connection.config[:port].to_s,
        "rack.errors"         => $stderr,
        "rack.multithread"    => false,
        "rack.multiprocess"   => false,
        "rack.run_once"       => false,
        "rack.url_scheme"     => "http",
        "hatetepe.connection" => @connection,
        "async.callback"      => method(:respond)
      })
    end
  end
end

module Hatetepe::Server
  class RackApp
    def initialize(app, connection)
      @app, @connection = app, connection
    end

    def call(request, &respond)
      env = env_for(request)
      env["async.callback"] = proc do |response|
        async_callback(response, &respond)
      end

      response = [ -1 ]
      catch :async do
        response = @app.call(env)
      end

      async_callback(response, &respond)
    end

    def async_callback(response, &respond)
      if response[0] >= 0
        respond.call(Hatetepe::Response.new(*response))
      end
    end

    def env_for(request)
      request.to_h.merge({
        "SERVER_NAME"       => @connection.config[:host],
        "SERVER_PORT"       => @connection.config[:port].to_s,
        "rack.errors"       => $stderr,
        "rack.multithread"  => false,
        "rack.multiprocess" => false,
        "rack.run_once"     => false,
        "rack.url_scheme"   => "http"
      })
    end
  end
end

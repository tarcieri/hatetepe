module Hatetepe::Server
  class RackApp
    def initialize(app, connection)
      @app, @connection = app, connection
    end

    def call(request, &respond)
      @request, @respond = request, respond

      response = [ -1, {}, [] ]
      catch :async do
        env                   = env_for(request)
        env["async.callback"] = method(:async_callback)
        env["rack.proxy"]     = method(:rack_proxy)
        response              = @app.call(env)
      end

      respond(response)
    ensure
      @request, @response = nil, nil
    end

    def respond(response)
      if response[0] >= 0
        @respond.call(Hatetepe::Response.new(*response))
      end
    end

    def async_callback(response)
      respond(response)
    end

    def rack_proxy(uri)
      Hatetepe::Proxy.new(uri).call(@request, &response)
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

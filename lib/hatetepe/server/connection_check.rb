require "rack/utils"

Rack::Utils::HTTP_STATUS_CODES[499] = "Client Closed Connection"

class Hatetepe::Server
  CONN_CLOSED_RESPONSE = [499, {"Content-Type" => "text/html"},
                          ["Client Closed Request"]].freeze

  class ConnectionCheck
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def call(env)
      async_cb = env["async.callback"]
      env["async.callback"] = proc do |response|
        async_cb.call choose_response(env, response)
      end

      choose_response(env, app.call(env))
    end

    def choose_response(env, response)
      if response[0] != -1 && env["hatetepe.connection"].closed?
        CONN_CLOSED_RESPONSE
      else
        response
      end
    end
  end
end

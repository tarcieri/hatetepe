module Hatetepe::Server
  class Pipeline
    def initialize(app, connection)
      @requests, @app = [], app
    end

    def call(request, &respond)
      begin
        previous  =  @requests.last
        @requests << request
        @app.call(request) do |response|
          EM::Synchrony.sync(previous) if previous
          respond.call(response)
        end
      ensure
        @requests.delete(request)
      end
    end
  end
end

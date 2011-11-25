class Hatetepe::Client
  class KeepAlive
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(request)
      app.call request
    end
  end
end

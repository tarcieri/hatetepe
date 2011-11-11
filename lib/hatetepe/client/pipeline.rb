require "em-synchrony"

class Hatetepe::Client
  class Pipeline
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(request)
      previous = request.connection.requests[-2]
      defer = request.connection.pending_requests[previous.object_id]
      EM::Synchrony.sync defer if previous != request && defer
      
      app.call request
    end
  end
end

require "em-synchrony"

class Hatetepe::Client
  class Pipeline
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(request)
      previous = request.connection.requests[-2]
      lock = request.connection.pending_transmission[previous.object_id]
      EM::Synchrony.sync lock if previous != request && lock
      
      app.call request
    end
  end
end

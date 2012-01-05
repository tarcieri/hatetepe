require "em-synchrony"

class Hatetepe::Server
  # TODO move specs from server_spec.rb to server/pipeline_spec.rb
  class Pipeline
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      previous = env["hatetepe.connection"].requests[-2]
      
      stream_start = env["stream.start"]
      env["stream.start"] = proc do |response|
        EM::Synchrony.sync previous if previous
        stream_start.call response
      end
      
      app.call env
    end
  end
end

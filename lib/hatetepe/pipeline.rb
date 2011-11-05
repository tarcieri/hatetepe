module Hatetepe
  # TODO move specs from server_spec.rb to pipeline_spec.rb
  class Pipeline
    attr_reader :app
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      previous, request = env["hatetepe.connection"].requests.values_at(-2, -1)
      blocks = env.values_at("stream.start", "stream.close")
      
      env["stream.start"] = proc do |response|
        EM::Synchrony.sync previous if previous
        blocks[0].call response
      end
      
      env["stream.close"] = proc do
        blocks[1].call
        request.succeed
      end
      
      app.call env
    end
  end
end

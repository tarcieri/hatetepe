begin
  require "awesome_print"
rescue LoadError; end

require "em-synchrony"
require "fakefs/safe"

RSpec.configure do |config|
  config.before :each do
    ENV["RACK_ENV"] = "testing"
  end
  
  config.before :all do
    EM.class_eval do
      class << self
        attr_reader :spec_hooks
        def synchrony_with_hooks(blk = nil, tail = nil, &block)
          synchrony_without_hooks do
            (blk || block).call
            @spec_hooks.each &:call
          end
        end
        alias_method :synchrony_without_hooks, :synchrony
        alias_method :synchrony, :synchrony_with_hooks
      end
    end
  end
  
  config.after :all do
    EM.class_eval do
      class << self
        remove_method :spec_hooks
        alias_method :synchrony, :synchrony_without_hooks
        remove_method :synchrony_with_hooks
      end
    end
  end
  
  config.before :each do
    EM.instance_variable_set :@spec_hooks, []
  end
  
  config.after :each do
    EM.instance_variable_set :@spec_hooks, nil
  end
  
  def secure_reactor(timeout = 0.05, &expectations)
    finished = false
    location = caller[0]
    
    EM.spec_hooks << proc do
      EM.add_timer(timeout) do
        EM.stop
        fail "Timeout exceeded (#{location})" unless finished
      end
    end
    EM.spec_hooks << proc do
      expectations.call
      finished = true
    end
  end
  
  def command(opts, timeout = 0.05, &expectations)
    secure_reactor timeout, &expectations
    Hatetepe::CLI.start opts.split
  end
end

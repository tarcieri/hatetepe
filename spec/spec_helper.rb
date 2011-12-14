begin
  require "awesome_print"
rescue LoadError; end

require "em-synchrony"
require "fakefs/safe"

RSpec.configure do |config|
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
end

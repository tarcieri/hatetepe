begin
  require "awesome_print"
rescue LoadError; end

require "em-synchrony"
require "em-synchrony/em-http"
require "fakefs/safe"

RSpec.configure {|config|
  config.before {
    EM.class_eval {
      @spec_hooks = []
      class << self
        attr_reader :spec_hooks
        def synchrony_with_hooks(blk = nil, tail = nil, &block)
          synchrony_without_hooks do
            (blk || block).call
            @spec_hooks.each {|sh| sh.call }
          end
        end
        alias_method :synchrony_without_hooks, :synchrony
        alias_method :synchrony, :synchrony_with_hooks
      end
    }
  }
  
  config.after {
    EM.class_eval {
      @spec_hooks = nil
      class << self
        remove_method :spec_hooks
        alias_method :synchrony, :synchrony_without_hooks
        remove_method :synchrony_with_hooks
      end
    }
  }
}

module Hatetepe
  module Events
    def self.included(klass)
      klass.extend ClassMethods
    end
    
    attr_reader :state
    
    def event(name, *args)
      send(:"on_#{name}").each {|blk| blk.call *args }
    end
    
    def event!(name, *args)
      @state = name
      event(name, *args)
    end
    
    module ClassMethods
      def events(*event_names)
        event_names.each {|name|
          define_method(:"on_#{name}") {|&block|
            ivar = :"@on_#{name}"
            store = instance_variable_get(ivar)
            store ||= instance_variable_set(ivar, [])
            
            return store unless block
            store << block
          }
          
          define_method(:"#{name}?") {
            instance_variable_get(:@state) == name
          }
        }
      end
    end
  end
end

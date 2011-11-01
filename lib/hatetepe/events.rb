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
      event name, *args
    end
    
    module ClassMethods
      def event(name, *more_names)
        define_method :"on_#{name}" do |&block|
          ivar = :"@on_#{name}"
          store = instance_variable_get(ivar)
          store ||= instance_variable_set(ivar, [])
          
          return store unless block
          store << block
        end
        
        define_method(:"#{name}?") { state == name }
        
        more_names.each &method(:event)
      end
    end
  end
end

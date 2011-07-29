require "em-synchrony"
require "eventmachine"
require "stringio"

module Hatetepe
  class Body < StringIO
    include EM::Deferrable
    
    def sync
      EM::Synchrony.sync self
    end
    
    def empty?
      length == 0
    end
  end
end

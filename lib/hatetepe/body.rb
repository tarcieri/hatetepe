require "em-synchrony"
require "eventmachine"
require "stringio"

module Hatetepe
  class Body
    include EM::Deferrable
    
    attr_reader :io
    attr_accessor :source
    
    def initialize(string = "")
      @receivers = []
      @io = StringIO.new(string)
    end
    
    def sync
      source.resume if source && source.paused?
      EM::Synchrony.sync self
    end
    
    def length
      # TODO maybe I want to #sync here
      @io.length
    end
    
    def empty?
      length == 0
    end
    
    def pos
      @io.pos
    end
    
    def rewind
      @io.rewind
    end
    
    def close_write
      ret = @io.close_write
      succeed
      ret
    end
    
    def closed_write?
      @io.closed_write?
    end
    
    def each(&block)
      @receivers << block
      block.call @io.string.dup unless @io.string.empty?
      sync
    end
    
    def read(*args)
      sync
      rewind
      @io.read *args
    end
    
    def gets
      sync
      rewind
      @io.gets
    end
    
    def write(chunk)
      ret = @io.write chunk
      @receivers.each {|r| r.call chunk }
      ret
    end
    
    def <<(chunk)
      ret = @io << chunk
      @receivers.each {|r| r.call chunk }
      ret
    end
  end
end
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
      
      callback {
        rewind
        close_write unless closed_write?
      }
    end
    
    def sync
      source.resume if source && source.paused?
      EM::Synchrony.sync self
    end
    
    def length
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
      @io.close_write
      succeed
    end
    
    def closed_write?
      @io.closed_write?
    end
    
    def each(&block)
      @receivers << block
      block.call @io.string unless @io.string.empty?
      sync
    ensure
      @receivers.delete block
    end
    
    def read(length = nil, buffer = nil)
      sync
      if buffer.nil?
        @io.read length
      else
        @io.read length, buffer
      end
    end
    
    def gets
      sync
      @io.gets
    end
    
    def write(chunk)
      @io.write chunk
      @receivers.each {|r| r.call chunk }
    end
    
    def <<(chunk)
      @io << chunk
      @receivers.each {|r| r.call chunk }
    end
  end
end

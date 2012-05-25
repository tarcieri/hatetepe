require "em-synchrony"
require "eventmachine"
require "stringio"

require "hatetepe/deferred_status_fix"

module Hatetepe
  # Thin wrapper around StringIO for asynchronous body processing.
  class Body
    include EM::Deferrable
    
    # The wrapped StringIO.
    attr_reader :io
    
    # The origin Client or Server connection.
    attr_accessor :source
    
    # Create a new Body instance.
    #
    # @param [String] data
    #   Initial content of the StringIO object.
    def initialize(data = "")
      @receivers = []
      @io = StringIO.new(data)
    end
    
    # Blocks until the Body is write-closed.
    #
    # Use this if you want to wait until _all_ of the body has arrived before
    # continuing. It will resume the originating connection if it's paused.
    #
    # @return [undefined]
    def sync
      source.resume if source && source.paused?
      EM::Synchrony.sync self
    end
    
    # Forwards to StringIO#length.
    #
    # Blocks until the Body is write-closed. Returns the current length of the
    # underlying StringIO's content.
    #
    # @return [Fixnum]
    #   The StringIO's length.
    def length
      sync
      io.length
    end
    
    # Returns true if the underlying StringIO is empty, false otherwise.
    #
    # @return [Boolean]
    #   True if empty, false otherwise.
    def empty?
      length == 0
    end
    
    # Forwards to StringIO#pos.
    #
    # Returns the underlying StringIO's current pointer position.
    #
    # @return [Fixnum]
    #   The current pointer position.
    def pos
      io.pos
    end
    
    # Forwards to StringIO#rewind.
    #
    # Moves the underlying StringIO's pointer back to the beginnung.
    #
    # @return [undefined]
    def rewind
      sync
      rewind!
    end

    # Rewinds underlying IO without blocking
    #
    # TODO this is a hack. the whole blocking/rewinding stuff needs to be
    #      more though out.
    #
    # @api protected
    def rewind!
      io.rewind
    end
    
    # Forwards to StringIO#close_write.
    #
    # Write-closes the body and succeeds, thus releasing all blocking method
    # calls like #length, #each, #read and #get.
    #
    # @return [undefined]
    def close_write
      io.close_write
      succeed
    end
    
    # Forwards to StringIO#closed_write?.
    #
    # Returns true if the body is write-closed, false otherwise.
    #
    # @return [Boolean]
    #   True if the body is write-closed, false otherwise.
    def closed_write?
      io.closed_write?
    end
    
    # Yields incoming body data.
    #
    # Immediately yields all data that has already arrived. Blocks until the
    # Body is write-closed and yields for each call to #write until then.
    #
    # @yield [String] Block to execute for each incoming data chunk.
    #
    # @return [undefined]
    def each(&block)
      @receivers << block
      block.call io.string.dup unless io.string.empty?
      sync
    end
    
    # Forwards to StringIO#read.
    #
    # From the Rack Spec: If given, +length+ must be a non-negative Integer
    # (>= 0) or +nil+, and +buffer+ must be a String and may not be nil. If
    # +length+ is given and not nil, then this method reads at most +length+
    # bytes from the input stream. If +length+ is not given or nil, then this
    # method reads all data until EOF. When EOF is reached, this method returns
    # nil if +length+ is given and not nil, or "" if +length+ is not given or
    # is nil. If +buffer+ is given, then the read data will be placed into
    # +buffer+ instead of a newly created String object.
    #
    # @param [Fixnum] length (optional)
    #   How many bytes to read.
    # @param [String] buffer (optional)
    #   Buffer for read data.
    #
    # @return [nil]
    #   +nil+ if EOF has been reached.
    # @return [String]
    #   All data or at most +length+ bytes of data if +length+ is given.
    def read(*args)
      sync
      io.read *args
    end
    
    # Forwards to StringIO#gets.
    #
    # Reads one line from the IO. Returns the line or +nil+ if EOF has been
    # reached.
    #
    # @return [String]
    #   One line.
    # @return [nil]
    #   If has been reached.
    def gets
      sync
      io.gets
    end
    
    # Forwards to StringIO#write.
    #
    # Appends the given String to the underlying StringIO annd returns the
    # number of bytes written.
    #
    # @param [String] data
    #   The data to append.
    #
    # @return [Fixnum]
    #   The number of bytes written.
    def write(data)
      ret = io.write data
      @receivers.each do |r|
        Fiber.new { r.call data }.resume
      end
      ret
    end
  end
end

require "em-synchrony"
require "eventmachine"
require "pathname"
require "stringio"
require "tempfile"

require "hatetepe/deferred_status_fix"

module Hatetepe
  # Thin wrapper around StringIO for asynchronous body processing.
  class Body
    include EM::Deferrable
    
    # The wrapped File, Tempfile or StringIO.
    attr_reader :io
    
    # A Client or Server connection that's the data source
    attr_accessor :connection

    # Length of the data, according to its source.
    attr_accessor :connection_length

    # Create a new Body instance.
    #
    # @param [File|StringIO|Tempfile] io
    #   IO object that's supposed to be wrapped for async processing.
    def initialize(io = StringIO.new, length = nil)
      @receivers = []
      @io = io, @length = length
    end
    
    # Blocks until the Body is write-closed.
    #
    # Use this if you want to wait until _all_ of the body has arrived before
    # continuing. It will resume the originating connection if it's paused.
    #
    # TODO maybe find a better name for this as there's already IO#sync.
    #
    # @return [undefined]
    def sync
      connection.resume if connection && connection.paused?
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
      connection_length || (sync; io.length)
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
      io.rewind
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
      # don't write more data than the source connection said it would send.
      if connection_length && (io.length + data.length > connection_length)
        data = data[0..(connection_length - io.length)]
        return if data.empty?
      end

      ret = io.write data
      @receivers.each {|r| r.resume data }
      ret
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
      receive &block
      
      # let the receiver have all the data that has already been received
      actual_pos, io.pos = io.pos, 0
      data = io.read
      @receivers.each {|r| r.resume data } unless data.empty?
      io.pos = actual_pos

      sync
    end
  end

  def receive(&block)
    # maybe we can reuse the current fiber for this
    @receivers << Fiber.new do |data|
      while data
        block.call data
        data = Fiber.yield
      end
    end
  end

  def succeed
    # let all receivers die
    @receivers.each {|r| r.resume false }

    super
  end
end

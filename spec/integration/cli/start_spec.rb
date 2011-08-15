require "spec_helper"
require "hatetepe/cli"
require "socket"

describe "start command" do
  def hook_event_loop(&block)
    EM.spec_hooks << block
  end
  
  def add_stop_timer(timeout)
    hook_event_loop do
      EM.add_timer(timeout) { EM.stop }
    end
  end
  
  before do
    $stderr = StringIO.new ""
    
    FakeFS.activate!
    File.open("config.ru", "w") do |f|
      f.write %q{run proc {|e| [200, {"Content-Type" => "text/plain"}, [e["REQUEST_URI"]]] }}
    end
    File.open("config2.ru", "w") do |f|
      f.write %q{run proc {|e| [200, {"Content-Type" => "text/plain"}, ["config2.ru loaded"]] }}
    end
  end
  
  after do
    $stderr = STDERR
    
    FakeFS.deactivate!
    FakeFS::FileSystem.clear
  end
  
  it "starts an instance of Rity" do
    add_stop_timer 0.01
    hook_event_loop do
      Socket.tcp("127.0.0.1", 3000) {|*| }
    end
    Hatetepe::CLI.start %w{}

    $stderr.string.should include("127.0.0.1:3000")
  end
  
  it "answers HTTP requests" do
    add_stop_timer 0.02
    hook_event_loop do
      request = EM::HttpRequest.new("http://127.0.0.1:3000").aget
      response = EM::Synchrony.sync(request)
      
      response.response_header.status.should == 200
      response.response_header["CONTENT_TYPE"].should == "text/plain"
      response.response.should == "/"
    end
    Hatetepe::CLI.start %w{}
  end
  
  describe "--port option" do
    it "changes the listen port" do
      add_stop_timer 0.01
      hook_event_loop do
        Socket.tcp("127.0.0.1", 3001) {|*| }
      end
      Hatetepe::CLI.start %w{--port=3001}
      
      $stderr.string.should include(":3001")
    end
    
    it "has an alias: -p" do
      add_stop_timer 0.01
      hook_event_loop do
        Socket.tcp("127.0.0.1", 3002) {|*| }
      end
      Hatetepe::CLI.start %w{-p 3002}
      
      $stderr.string.should include(":3002")
    end
  end
  
  describe "--bind option" do
    it "changes the listen interface" do
      add_stop_timer 0.01
      hook_event_loop do
        Socket.tcp("127.0.0.2", 3000) {|*| }
      end
      Hatetepe::CLI.start %w{--bind=127.0.0.2}
      
      $stderr.string.should include("127.0.0.2:")
    end
    
    it "has an alias: -b" do
      add_stop_timer 0.01
      hook_event_loop do
        Socket.tcp("127.0.0.3", 3000) {|*| }
      end
      Hatetepe::CLI.start %w{-b 127.0.0.3}
      
      $stderr.string.should include("127.0.0.3:")
    end
  end
  
  describe "--rackup option" do
    it "changes the rackup file that'll be loaded" do
      add_stop_timer 0.01
      hook_event_loop do
        request = EM::HttpRequest.new("http://127.0.0.1:3000").aget
        response = EM::Synchrony.sync(request)
        response.response.should include("config2.ru")
      end
      Hatetepe::CLI.start %w{--rackup=config2.ru}
    end
    
    it "has an alias: -r" do
      add_stop_timer 0.01
      hook_event_loop do
        request = EM::HttpRequest.new("http://127.0.0.1:3000").aget
        response = EM::Synchrony.sync(request)
        response.response.should include("config2.ru")
      end
      Hatetepe::CLI.start %w{-r config2.ru}
    end
  end
  
  describe "--quiet option" do
    it "discards all output" do
      pending
      
      add_stop_timer 0.01
      Hatetepe::CLI.start %w{--quiet}
      
      $stderr.string.should be_empty
    end
    
    it "has an alias: -q" do
      pending
      
      add_stop_timer 0.01
      Hatetepe::CLI.start %w{-q}
      
      $stderr.string.should be_empty
    end
  end
  
  describe "--verbose option" do
    it "prints debugging data" do
      pending
      
      add_stop_timer 0.01
      hook_event_loop do
        request = EM::HttpRequest.new("http://127.0.0.1:3000").aget
      end
      Hatetepe::CLI.start %w{--verbose}
      
      $stderr.string.split("\n").size.should > 10
    end

    it "has an alias: -V" do
      pending
      
      add_stop_timer 0.01
      hook_event_loop do
        request = EM::HttpRequest.new("http://127.0.0.1:3000").aget
      end
      Hatetepe::CLI.start %w{-V}
      
      $stderr.string.split("\n").size.should > 10
    end
  end
end

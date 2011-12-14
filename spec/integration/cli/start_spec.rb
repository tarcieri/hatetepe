require "spec_helper"
require "hatetepe/cli"

describe "The `hatetepe start' command" do
  before do
    $stderr = StringIO.new
    
    FakeFS.activate!
    File.open "config.ru", "w" do |f|
      f.write 'run proc {|env| [200, {}, ["Hello world!"]] }'
    end
    File.open "config2.ru", "w" do |f|
      f.write 'run proc {|env| [501, {}, ["Herp derp"]] }'
    end
  end
  
  after do
    $stderr = STDERR
    
    FakeFS.deactivate!
    FakeFS::FileSystem.clear
  end
  
  describe "without options" do
    it "starts a Hatetepe::Server with default options" do
      command "" do
        Socket.tcp("127.0.0.1", 3000) {|*| }
        $stderr.string.should include("config.ru", "127.0.0.1:3000")
      end
    end
    
    it "serves HTTP requests" do
      command "" do
        Hatetepe::Client.get("http://127.0.0.1:3000").tap do |response|
          response.status.should equal(200)
          response.body.read.should == "Hello world!"
        end
      end
    end
  end
  
  ["--port", "-p"].each do |opt|
    describe "with #{opt} option" do
      it "binds the Hatetepe::Server to the specified TCP port" do
        command "#{opt} 3002" do
          Socket.tcp("127.0.0.1", 3002) {|*| }
        end
      end
    end
  end
  
  ["--bind", "-b"].each do |opt|
    describe "with #{opt} option" do
      it "binds the Hatetepe::Server to the specified TCP interface" do
        command "#{opt} 127.0.0.2" do
          Socket.tcp("127.0.0.2", 3000) {|*| }
        end
      end
    end
  end
  
  ["--rackup", "-r"].each do |opt|
    describe "with #{opt} option" do
      it "loads the specified rackup (.ru) file" do
        command "#{opt} config2.ru" do
          Hatetepe::Client.get("http://127.0.0.1:3000").tap do |response|
            response.status.should equal(501)
            response.body.read.should == "Herp derp"
          end
        end
      end
    end
  end
  
  ["--verbose", "-v"].each do |opt|
    describe "with #{opt} option" do
      it "prints debugging data" do
        pending
      end
    end
  end
  
  ["--quiet", "-q"].each do |opt|
    describe "with #{opt} option" do
      it "discards all output" do
        pending
      end
    end
  end
end

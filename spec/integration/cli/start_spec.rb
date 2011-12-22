require "spec_helper"
require "hatetepe/cli"

describe "The `hatetepe start' command" do
  before do
    ENV.delete "RACK_ENV"
    
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
        ENV["RACK_ENV"].should == "development"
        $stderr.string.should include("config.ru", "127.0.0.1:3000", "development")
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
  
  ["--env", "-e"].each do |opt|
    describe "with #{opt} option" do
      it "boots the app in the specified environment" do
        command "#{opt} herpderp" do
          ENV["RACK_ENV"].should == "herpderp"
        end
      end
      
      ["dev", "devel", "develop"].each do |value|
        it "expands #{value} to `development'" do
          command "#{opt} #{value}" do
            ENV["RACK_ENV"].should == "development"
          end
        end
      end
      
      it "expands test to `testing'" do
        command "#{opt} test" do
          ENV["RACK_ENV"].should == "testing"
        end
      end
    end
  end
  
  ["--keepalive", "-k"].each do |opt|
    describe "with #{opt} option" do
      it "timeouts a connection after the specified amount of seconds" do
        command "#{opt} 1.5", 1.6 do
          Socket.tcp "127.0.0.1", 3000 do |s|
            s.should be_healthy
            
            sleep 1.45
            s.should be_healthy
            
            sleep 0.1
            s.should be_healthy
          end
        end
      end
    end
  end
end

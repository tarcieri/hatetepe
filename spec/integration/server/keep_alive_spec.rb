require "spec_helper"
require "hatetepe/cli"
require "hatetepe/server"

describe Hatetepe::Server, "with Keep-Alive" do
  before do
    $stderr = StringIO.new
    
    FakeFS.activate!
    File.open "config.ru", "w" do |f|
      f.write 'run proc {|env| [200, {"Content-Type" => "text/plain"}, []] }'
    end
  end
  
  after do
    $stderr = STDERR
    
    FakeFS.deactivate!
    FakeFS::FileSystem.clear
  end
  
  let :client do
    Hatetepe::Client.start :host => "127.0.0.1", :port => 30001
  end
  
  let :server do
    Hatetepe::Server.any_instance
  end
  
  it "keeps the connection open for 1 seconds by default" do
    command "-p 30001", 1.1 do
      client
      EM::Synchrony.sleep 0.95
      client.should_not be_closed
      EM::Synchrony.sleep 0.1
      client.should be_closed
    end
  end
  
  describe "and :timeout option" do
    it "times out the connection after the specified amount of time" do
      command "-p 30001 -t 0.5", 0.6 do
        client
        EM::Synchrony.sleep 0.45
        client.should_not be_closed
        EM::Synchrony.sleep 0.1
        client.should be_closed_by_remote
      end
    end
  end
  
  describe "and :timeout option set to 0" do
    it "keeps the connection open until the client closes it" do
      command "-p 30001 -t 0", 2 do
        client
        EM::Synchrony.sleep 1.95
        client.should_not be_closed
      end
    end
  end
  
  it "closes the connection if the client sends Connection: close" do
    command "-p 30001" do
      client.get("/", "Connection" => "close").tap do |response|
        response.headers["Connection"].should == "close"
        EM::Synchrony.sync response.body
        client.should be_closed_by_remote
      end
    end
  end
  
  it "sends Connection: keep-alive if the client also sends it" do
    command "-p 30001" do
      client.get("/", "Connection" => "keep-alive").tap do |response|
        response.headers["Connection"].should == "keep-alive"
      end
    end
  end
  
  ["1.0", "0.9"].each do |version|
    describe "and an HTTP #{version} client" do
      after { ENV.delete "DEBUG_KEEP_ALIVE" }
      
      it "closes the connection after one request" do
        pending "http_parser.rb doesn't parse HTTP/0.9" if version == "0.9"
        
        ENV["DEBUG_KEEP_ALIVE"] = "yes please"
        
        command "-p 30001" do
          client.get("/", {"Connection" => ""}, nil, version).tap do |response|
            response.headers["Connection"].should == "close"
            EM::Synchrony.sync response.body
            client.should be_closed_by_remote
          end
        end
      end
    end
  end
end

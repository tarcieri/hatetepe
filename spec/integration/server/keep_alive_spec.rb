require "spec_helper"
require "hatetepe/cli"
require "hatetepe/server"

describe Hatetepe::Server, "with Keep-Alive" do
  before do
    $stderr = StringIO.new
    
    FakeFS.activate!
    File.open "config.ru", "w" do |f|
      f.write 'run proc {|env| [200, {"Content_Type" => "text/plain"}, []] }'
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
  
  it "keeps the connection open for 5 seconds by default" do
    command "-p 30001", 5.1 do
      server.should_not_receive :close_connection
      client.get("/").status.should equal(200)
      EM::Synchrony.sleep 4.9
      
      server.should_receive :close_connection
      EM::Synchrony.sleep 0.1
      
      EM.stop
    end
  end
  
  describe "and :keepalive option" do
    it "times out the connection after the specified amount of time" do
      command "-p 30001 -k 1.5", 1.6 do
        server.should_not_receive :stop!
        client
        sleep 1.45
        server.should_receive :stop!
        sleep 0.05
        
        EM.stop
      end
    end
  end
  
  describe "and :keepalive option set to 0" do
    it "keeps the connection open until the client closes it" do
      command "-p 30001 -k 0", 6 do
        server.should_not_receive :stop!
        client
        sleep 5.95
        server.should_receive :stop!
        
        EM.stop
      end
    end
  end
  
  it "closes the connection if the client sends Connection: close" do
    command "-p 30001", 0.1 do
      server.should_receive :stop!
      client.get("/", "Connection" => "close").tap do |response|
        response.headers["Connection"].should == "close"
      end
      
      EM.stop
    end
  end
  
  it "sends Connection: keep-alive if the client also sends it" do
    command "-p 30001", 0.1 do
      client.get("/", "Connection" => "keep-alive").tap do |response|
        response.headers["Connection"].should == "keep-alive"
      end
      
      EM.stop
    end
  end
  
  [1.0, 0.9].each do |version|
    describe "and an HTTP #{version} client" do
      it "closes the connection after one request" do
        command "-p 30001", 0.1 do
          server.should_receive :stop!
          client.get("/", {}, nil, version).tap do |response|
            response.headers["Connection"].should == "close"
          end
          
          EM.stop
        end
      end
    end
  end
end

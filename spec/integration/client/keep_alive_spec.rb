require "hatetepe/cli"
require "hatetepe/client"
require "spec_helper"
require "stringio"

describe Hatetepe::Client, "with Keep-Alive" do
  before do
    $stderr = StringIO.new
    
    FakeFS.activate!
    File.open "config.ru", "w" do |f|
      f.write 'run proc {|env| [200, {"Content_Type" => "text/plain"}, []] }'
    end
    File.open "config_close.ru", "w" do |f|
      f.write 'run proc {|env| [200, {"Content-Type" => "text/plain",
                                      "Connection" => "close"}, []] }'
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
  
  it "keeps the connection open" do
    command "-p 30001", 3.1 do
      client.should_not_receive :close!
      EM::Synchrony.sleep 3
      
      EM.stop
    end
  end
  
  describe "and :keepalive option" do
    let :client do
      Hatetepe::Client.start :host => "127.0.0.1", :port => 30001, :keepalive => 0.1
    end
    
    it "times out the connection after the specified amount of seconds" do
      command "-p 30001", 0.2 do
        client.should_receive :stop!
        EM::Synchrony.sleep 0.15
        
        EM.stop
      end
    end
  end
  
  it "closes the connection after an obviously single request" do
    command "-p 30001", 0.15 do
      Hatetepe::Client.any_instance.should_receive :stop!
      Hatetepe::Client.get("/").status.should equal(200)
      
      EM.stop
    end
  end
  
  it "closes the connection if the server tells it to" do
    command "-p 30001 -r config_close.ru", 0.1 do
      client.should_receive :stop!
      client.get("/").status.should equal(200)
      
      EM.stop
    end
  end
end

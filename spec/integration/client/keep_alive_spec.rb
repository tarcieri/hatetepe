require "hatetepe/cli"
require "hatetepe/client"
require "spec_helper"
require "stringio"
require "yaml"

describe Hatetepe::Client, "with Keep-Alive" do
  before do
    $stderr = StringIO.new
    
    FakeFS.activate!
    File.open "config.ru", "w" do |f|
      f.write 'run proc {|env| [200,
                                {"Content_Type" => "text/plain"},
                                [env["HTTP_CONNECTION"]]] }'
    end
    File.open "config_close.ru", "w" do |f|
      f.write 'run proc {|env| [200,
                                {"Content-Type" => "text/plain",
                                 "Connection" => "close"},
                                [env["HTTP_CONNECTION"]]] }'
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
    command "-p 30001", 2 do
      client
      EM::Synchrony.sleep 1.95
      client.should_not be_closed_by_self
    end
  end
  
  it "sends Connection: keep-alive" do
    command "-p 30001" do
      client.get("/").body.read.should == "keep-alive"
    end
  end
  
  describe "and an obviously single request" do
    it "sends Connection: close" do
      command "-p 30001" do
        Hatetepe::Client.get "http://127.0.0.1:30001/" do |response|
          YAML.load(response.body.read).should == "close"
        end
      end
    end
    
    it "closes the connection immediately after the response" do
      command "-p 30001" do
        #Hatetepe::Client.any_instance.should_receive :stop
        Hatetepe::Client.get "http://127.0.0.1:30001/"
      end
    end
  end
  
  it "closes the connection if the server tells it to" do
    #pending "Server can't send Conn: close as its Keep-Alive middleware overwrites it"
    command "-p 30001 -r config_close.ru" do
      client.get "/"
      client.should be_closed
    end
  end
end

require "spec_helper"
require "hatetepe/server"

describe Hatetepe::Server do
  let(:server) {
    Hatetepe::Server.allocate.tap {|s|
      s.send :initialize, config
      s.post_init
      s.requests << request
    }
  }
  let(:request) { stub "request", :to_hash => env }
  let(:env) {
    {
      "rack.input" => Hatetepe::Body.new
    }
  }
  
  let(:app) { stub "app" }
  let(:log) { stub "log" }
  let(:host) { stub "host" }
  let(:port) { stub "port" }
  let(:config) {
    {
      :app => app,
      :log => log,
      :host => host,
      :port => port
    }
  }
  
  context ".start(config)" do
    it "starts an EventMachine server" do
      args = [host, port, Hatetepe::Server, config]
      EM.should_receive(:start_server).with(*args) { server }
      
      Hatetepe::Server.start(config).should equal(server)
    end
  end
  
  context "#initialize(config)" do
    let(:server) { Hatetepe::Server.allocate }
    let(:builder) { stub "app builder" }

    it "builds the app" do
      Rack::Builder.stub :new => builder
      builder.should_receive(:use).with Hatetepe::App
      builder.should_receive(:run).with app
      
      server.send :initialize, config
      server.app.should equal(builder)
    end
    
    it "sets up logging" do
      server.send :initialize, config
      server.log.should equal(log)
    end
  end
  
  context "#post_init" do
    let(:server) {
      Hatetepe::Server.allocate.tap {|s| s.post_init }
    }
    
    it "sets up the request queue" do
      server.requests.should be_an(Array)
      server.requests.should be_empty
    end
    
    it "sets up the parser" do
      server.parser.should respond_to(:<<)
      server.parser.on_request[0].should == server.requests.method(:<<)
    end
    
    it "sets up the builder" do
      server.builder.on_write[0].should == server.method(:send_data)
    end
  end
  
  context "#receive_data(data)" do
    it "feeds data into the parser" do
      data = stub("data")
      server.parser.should_receive(:<<).with data
      server.receive_data data
    end
    
    it "closes the connection if parsing fails" do
      server.parser.should_receive(:<<).and_raise(Hatetepe::ParserError)
      server.should_receive :close_connection
      
      server.receive_data "irrelevant data"
    end
  end
  
  context "#process" do
    it "puts useful stuff into env[]" do
      app.should_receive(:call) {|e|
        e.should equal(env)
        e["hatetepe.connection"].should equal(server)
        e["rack.input"].source.should equal(server)
        [-1]
      }
      server.process
    end
    
    it "calls the app within a new Fiber" do
      outer_fiber = Fiber.current
      app.should_receive(:call) {
        Fiber.current.should_not equal(outer_fiber)
        [-1]
      }
      server.process
    end
  end
  
  context "env[stream.start]" do
    let(:previous) { EM::DefaultDeferrable.new }
    let(:response) {
      [123, {"Key" => "value"}, Rack::STREAMING]
    }
    
    before {
      server.requests.unshift previous
      app.stub(:call) {|e| response }
    }
    
    it "waits for the previous request's response to finish" do
      server.builder.should_not_receive :response
      server.process
    end
    
    it "initiates the response" do
      server.builder.should_receive(:response) {|res|
        res[0].should == 123
        res[1]["Key"].should == "value"
        res[1]["Server"].should == "hatetepe/#{Hatetepe::VERSION}"
      }
      previous.succeed
      server.process
    end
  end
  
  context "env[stream.send]" do
    it "passes data to the builder" do
      app.stub(:call) {|e|
        e["stream.send"].should == server.builder.method(:body)
        [-1]
      }
      server.process
    end
  end
  
  context "env[stream.close]" do
    before {
      server.stub :close_connection
      server.builder.stub :complete
      request.stub :succeed
    }
    
    it "completes the response" do
      server.builder.should_receive :complete
      app.stub(:call) {|e|
        e["stream.close"].call
        [-1]
      }
      server.process
    end
    
    it "succeeds the request" do
      request.should_receive :succeed
      app.stub(:call) {|e|
        e["stream.close"].call
        [-1]
      }
      server.process
    end
    
    it "leaves the connection open" do
      server.should_not_receive :close_connection
      app.stub(:call) {|e|
        server.requests << stub("another request")
        e["stream.close"].call
        [-1]
      }
      server.process
    end
    
    it "closes the connection if there are no more requests" do
      server.should_receive(:close_connection).with true
      app.stub(:call) {|e|
        e["stream.close"].call
        [-1]
      }
      server.process
    end
  end
end

require "spec_helper"
require "hatetepe/server"

describe Hatetepe::Server do
  let(:server) {
    Hatetepe::Server.allocate.tap {|s|
      s.send :initialize, config
      s.stub :comm_inactivity_timeout=
      s.post_init
      s.requests << request
    }
  }
  let(:request) { Hatetepe::Request.new :get, "/" }
  let(:env) { request.to_h }
  
  let(:app) { stub "app" }
  let(:host) { "127.0.4.1" }
  let(:port) { 8081 }
  let(:errors) { stub "errors", :<< => nil, :flush => nil }
  let(:config) {
    {
      :app => app,
      :host => host,
      :port => port,
      :errors => errors,
      :timeout => 0.0123
    }
  }
  
  before do
    server.stub :sockaddr => [42424, "127.0.42.1"]
    @old_env, ENV["RACK_ENV"] = ENV["RACK_ENV"], "testing"
  end
  
  after do
    ENV["RACK_ENV"] = @old_env
  end
  
  it "inherits from Hatetepe::Connection" do
    server.should be_a(Hatetepe::Connection)
  end
  
  context ".start(config)" do
    it "starts an EventMachine server" do
      args = [host, port, Hatetepe::Server, config]
      EM.should_receive(:start_server).with(*args) { server }
      
      Hatetepe::Server.start(config).should equal(server)
    end
  end
  
  context "#initialize(config)" do
    let(:server) { Hatetepe::Server.allocate }
    
    it "sets up the error stream" do
      server.send :initialize, config
      server.errors.should equal(errors)
      server.config[:errors].should be_nil
    end
    
    it "uses stderr as default error stream" do
      config.delete :errors
      server.send :initialize, config
      server.errors.should equal($stderr)
    end
    
    it "assumes a default connection inactivity timeout of 1 seconds" do
      server.send :initialize, {}
      server.config[:timeout].should equal(1)
    end
  end
  
  context "#post_init" do
    let :server do
      Hatetepe::Server.allocate.tap do |s|
        s.send :initialize, config
        s.stub :comm_inactivity_timeout=
      end
    end
    
    it "sets up the request queue" do
      server.post_init
      server.requests.should be_an(Array)
      server.requests.should be_empty
    end
    
    it "sets up the parser" do
      server.post_init
      server.parser.should respond_to(:<<)
      server.parser.on_request[0].should == server.requests.method(:<<)
    end
    
    it "sets up the builder" do
      server.post_init
      server.builder.on_write[0].should == server.method(:send_data)
    end
    
    it "builds the app" do
      server.post_init
      server.app.should be_a(Hatetepe::Server::Pipeline)
      server.app.app.should be_a(Hatetepe::Server::App)
      server.app.app.app.should be_a(Hatetepe::Server::KeepAlive)
      server.app.app.app.app.should be_a(Hatetepe::Server::Proxy)
      server.app.app.app.app.app.should equal(app)
    end
    
    it "starts the connection inactivity tracking" do
      server.should_receive(:comm_inactivity_timeout=).with 0.0123
      server.post_init
    end
    
    it "enables request processing" do
      server.post_init
      server.processing_enabled.should be_true
    end
  end
  
  context "#receive_data(data)" do
    before do
      ENV.delete "RACK_ENV"
      server.stub :close_connection
    end
    
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
    
    it "re-raises parsing errors if RACK_ENV is testing" do
      ENV["RACK_ENV"] = "testing"
      server.parser.should_receive(:<<).and_raise Hatetepe::ParserError
      
      expect {
        server.receive_data "irrelevant data"
      }.to raise_error(Hatetepe::ParserError)
    end
    
    it "closes the connection when catching an exception" do
      server.parser.should_receive(:<<).and_raise Exception
      server.should_receive :close_connection_after_writing
      
      server.receive_data ""
    end
    
    it "re-raises caught exceptions" do
      ENV["RACK_ENV"] = "testing"
      server.parser.should_receive(:<<).and_raise Exception
      
      expect { server.receive_data "" }.to raise_error(Exception)
    end
    
    it "logs caught exceptions" do
      server.parser.should_receive(:<<).and_raise "error message"
      errors.should_receive(:<<) {|str|
        str.should include("error message")
      }
      errors.should_receive :flush
      
      server.receive_data ""
    end
  end
  
  context "#process" do
    before do
      request.stub :to_h => env
      app.stub :call => [-1]
    end
    
    it "puts useful stuff into env[]" do
      app.should_receive(:call) {|e|
        e.should equal(env)
        e["rack.url_scheme"].should == "http"
        e["hatetepe.connection"].should equal(server)
        e["rack.input"].source.should equal(server)
        e["rack.errors"].should equal(server.errors)
        e["rack.multithread"].should be_false
        e["rack.multiprocess"].should be_false
        e["rack.run_once"].should be_false
        
        e["SERVER_NAME"].should == host
        e["SERVER_NAME"].should_not equal(host)
        e["SERVER_PORT"].should == String(port)
        e["REMOTE_ADDR"].should == server.remote_address
        e["REMOTE_ADDR"].should_not equal(server.remote_address)
        e["REMOTE_PORT"].should == String(server.remote_port)
        e["HTTP_HOST"].should == "#{host}:#{port}"
        
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
    
    it "is a no-op if processing is disabled" do
      server.processing_enabled = false
      app.should_not_receive :call
      server.process
    end
    
    let(:another_request) { Hatetepe::Request.new :get, "/asdf" }
    
    it "disables the connection timeout until the last request is finished" do
      server.requests << another_request
      
      server.should_receive(:comm_inactivity_timeout=).with 0
      server.process
      
      server.should_not_receive(:comm_inactivity_timeout=).with config[:timeout]
      server.requests.delete request
      request.succeed
      
      server.rspec_verify
      server.rspec_reset
      
      server.should_receive(:comm_inactivity_timeout=).with config[:timeout]
      server.requests.delete another_request
      another_request.succeed
    end
  end
  
  context "env[stream.start].call(response)" do
    let(:previous) { EM::DefaultDeferrable.new }
    let(:response) {
      [200, {"Key" => "value"}, Rack::STREAMING]
    }
    
    before {
      server.requests.unshift previous
      app.stub(:call) {|e| response }
      request.stub :succeed
      server.builder.stub :response_line
      server.builder.stub :headers
    }
    
    it "deletes itself from env[] to prevent multiple calls" do
      app.stub(:call) {|e|
        e["stream.start"].call response
        e.key?("stream.start").should be_false
        [-1]
      }
      previous.succeed
      server.process
    end
    
    # TODO this should be moved to a Server::Pipeline spec
    it "waits for the previous request's response to finish" do
      server.builder.should_not_receive :response
      server.process
    end
  end
  
  context "env[stream.send].call(chunk)" do
    it "passes data to the builder" do
      app.stub(:call) {|e|
        e["stream.send"].should == server.builder.method(:body_chunk)
        [-1]
      }
      server.process
    end
  end
  
  context "env[stream.close].call" do
    before {
      server.builder.stub :complete
      request.stub :succeed
    }
    
    it "leaves the connection open" do
      server.should_not_receive :close_connection
      app.stub(:call) {|e|
        server.requests << stub("another request")
        e["stream.close"].call
        [-1]
      }
      server.process
    end
    
    it "deletes itself and stream.send from env[] to prevent multiple calls" do
      app.stub(:call) {|e|
        e["stream.close"].call
        e.key?("stream.send").should be_false
        e.key?("stream.close").should be_false
        [-1]
      }
      server.process
    end
  end
  
  context "#start_response(response)" do
    let(:previous) { EM::DefaultDeferrable.new }
    let(:response) { [200, {"Key" => "value"}, Rack::STREAMING] }
    
    before {
      server.requests.unshift previous
      app.stub(:call) {|e| response }
      request.stub :succeed
      server.builder.stub :response_line
      server.builder.stub :headers
    }
    
    it "initiates the response" do
      server.builder.should_receive(:response_line) {|code|
        code.should equal(response[0])
      }
      server.builder.should_receive(:headers) {|headers|
        headers["Key"].should equal(response[1]["Key"])
        headers["Server"].should == "hatetepe/#{Hatetepe::VERSION}"
      }
      previous.succeed
      server.process
    end
  end
  
  context "#close_response(request)" do
    before do
      server.builder.stub :complete
      request.stub :succeed
      app.stub :call do |e|
        e["stream.close"].call
        [-1]
      end
    end
    
    it "removes the request from the request queue" do
      server.process
      server.requests.should be_empty
    end
    
    it "completes the response" do
      server.builder.should_receive :complete
      server.process
    end
    
    it "succeeds the request" do
      request.should_receive :succeed
      server.process
    end
  end
end

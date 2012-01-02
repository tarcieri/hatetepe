require "spec_helper"
require "hatetepe/client"

describe Hatetepe::Client do
  let(:client) do
    Hatetepe::Client.allocate.tap {|c| c.send :initialize, config }
  end
  let(:config) { stub "config" }
  
  let(:uri) { "http://example.net:8080/foo" }
  let(:parsed_uri) { URI.parse uri }
  let(:request) { Hatetepe::Request.new *request_as_array }
  let(:request_as_array) { ["GET", "/foo", {"Host" => "example.net:8080"}, [], "1.1"] }
  let(:headers) { {} }
  let(:body) { stub "body" }
  let(:response) { Hatetepe::Response.new 200 }
  
  it "inherits from Hatetepe::Connection" do
    client.should be_a(Hatetepe::Connection)
  end
  
  describe "#initialize(config)" do
    it "sets the config" do
      client.config.should equal(config)
    end
    
    it "creates the builder and parser" do
      client.parser.should be_a(Hatetepe::Parser)
      client.builder.should be_a(Hatetepe::Builder)
    end
    
    it "creates the requests list" do
      client.requests.should be_an(Array)
      client.requests.should be_empty
    end
    
    it "creates the lists of requests pending transmission or response" do
      client.pending_transmission.should be_a(Hash)
      client.pending_transmission.should be_empty
      client.pending_response.should be_a(Hash)
      client.pending_response.should be_empty
    end
    
    it "builds the app" do
      client.app.should be_a(Hatetepe::Client::KeepAlive)
      client.app.app.should be_a(Hatetepe::Client::Pipeline)
      client.app.app.app.should == client.method(:send_request)
    end
  end
  
  describe "#post_init" do
    it "wires the builder and parser" do
      client.post_init
      client.builder.on_write[0].should == client.method(:send_data)
      client.parser.on_response[0].should == client.method(:receive_response)
    end
    
    it "enables processing" do
      client.post_init
      client.processing_enabled.should be_true
    end
  end
  
  describe "#receive_data(data)" do
    let(:data) { stub "data" }
    
    it "feeds the data into the parser" do
      client.parser.should_receive(:<<).with data
      client.receive_data data
    end
    
    let(:error) { StandardError.new "alarm! eindringlinge! alarm!" }
    
    it "stops the client if it catches an error" do
      client.parser.should_receive(:<<).and_raise error
      client.should_receive :close_connection
      proc { client.receive_data data }.should raise_error(error)
    end
  end
  
  describe "#send_request(request)" do
    let(:entry) { stub "entry" }
    
    before do
      client.pending_transmission[request.object_id] = entry
      client.builder.stub :request
      entry.stub :succeed
      EM::Synchrony.stub :sync
    end
    
    it "feeds the request into the builder" do
      client.builder.should_receive(:request).with request_as_array
      client.send_request request
    end
    
    it "succeeds the request's entry in the pending transmission list" do
      entry.should_receive :succeed
      client.send_request request
    end
    
    it "adds the request to the pending response list and waits" do
      EM::Synchrony.should_receive(:sync) do |syncee|
        syncee.should respond_to(:succeed)
        client.pending_response[request.object_id].should equal(syncee)
      end
      client.send_request request
    end
    
    it "returns the waiting result" do
      EM::Synchrony.should_receive(:sync).and_return response
      client.send_request(request).should equal(response)
    end
    
    it "makes sure the request gets removed from the pending response list" do
      EM::Synchrony.should_receive(:sync).and_raise StandardError
      client.send_request request rescue nil
      client.pending_response.should be_empty
    end
  end
  
  describe "#receive_response(response)" do
    let(:requests) {
      [
        stub("request_with_response", :response => stub("response")),
        request,
        stub("another_request", :response => nil)
      ]
    }
    let(:id) { requests[1].object_id }
    
    before do
      client.stub :requests => requests
      client.pending_response[id] = stub("entry", :succeed => nil)
    end
    
    it "succeeds the pending response list entry of the first request without a response" do
      client.pending_response[id].should_receive(:succeed).with response
      client.receive_response response
    end
    
    it "associates the response with the corresponding request" do
      client.receive_response response
      request.response.should equal(response)
    end
  end
  
  describe "#<<(request)" do
    let(:fiber) { stub "fiber", :resume => nil }
    let(:app) { stub "app", :call => response }
    
    before do
      client.processing_enabled = true
      client.stub :app => app
      Fiber.stub(:new) {|blk| blk.call; fiber }
    end
    
    it "sets the request's connection" do
      request.should_receive(:connection=).with client
      client << request
    end
    
    it "adds the request to the requests list" do
      app.should_receive :call do
        client.requests[-1].should equal(request)
      end
      client << request
      client.requests.should be_empty
    end
    
    it "fails and ignores the request if processing is disabled" do
      client.processing_enabled = false
      request.should_receive :fail
      app.should_not_receive :call
      
      client << request
      request.connection.should equal(client)
    end
    
    it "adds the request to the pending transmission list" do
      app.should_receive :call do |req|
        client.pending_transmission[req.object_id].should respond_to(:succeed)
      end
      client << request
    end
    
    it "calls the app" do
      app.should_receive(:call).with request
      client << request
    end
    
    it "sets the response" do
      request.should_receive(:response=).with response
      client << request
    end
    
    it "succeeds the request if the response status indicates success" do
      request.should_receive(:succeed).with response
      client << request
    end
    
    it "fails the request if the response status indicates failure" do
      response.status = 403
      request.should_receive(:fail).with response
      client << request
    end
    
    it "fails the request if no response has been received"
    
    it "makes sure the request gets removed from the pending transmission list" do
      app.should_receive(:call).and_raise StandardError
      client << request rescue nil
      client.pending_transmission.should be_empty
    end
  end
  
  describe "#request(verb, uri, headers, body)" do
    let :config do
      {
        :host => "example.org",
        :port => 8080
      }
    end
    
    before do
      EM::Synchrony.stub :sync
      client.stub :<<
    end
    
    it "sets a Host header if none is set" do
      client.should_receive :<< do |request|
        request.headers["Host"].should == "example.org:8080"
      end
      client.request :get, uri
    end
    
    it "sets the User-Agent header" do
      client.should_receive :<< do |request|
        request.headers["User-Agent"].should == "hatetepe/#{Hatetepe::VERSION}"
      end
      client.request :get, uri
    end
    
    let(:user_agent) { stub "user-agent" }
    
    it "doesn't override an existing User-Agent header" do
      client.should_receive :<< do |request|
        request.headers["User-Agent"].should equal(user_agent)
      end
      client.request :get, uri, "User-Agent" => user_agent
    end
    
    describe "with Content-Type: application/x-www-form-urlencoded" do
      let :headers do
        {"Content-Type" => "application/x-www-form-urlencoded"}
      end
      
      let :body do
        [
          stub("body#1", :length => 12),
          stub("body#2", :length => 13),
          stub("body#3", :length => 14)
        ]
      end
      
      it "computes the body's length" do
        client.should_receive :<< do |request|
          request.headers["Content-Length"].should equal(39)
        end
        client.request :get, uri, headers, body
      end
      
      it "sets Content-Length to 0 if no body was passed" do
        client.should_receive :<< do |request|
          request.headers["Content-Length"].should equal(0)
        end
        client.request :get, uri, headers
      end
    end
    
    it "doesn't close the body" do
      body.should_not_receive :close_write
      client.request :get, uri, {}, body
    end
    
    it "passes the request to #<<" do
      client.should_receive :<< do |request|
        request.verb.should == "GET"
        request.uri.should == uri
        request.headers.should == headers
        request.body.should == [body]
      end
      client.request :get, uri, headers, body
    end
    
    it "waits until the requests succeeds" do
      EM::Synchrony.should_receive(:sync).with kind_of(Hatetepe::Request)
      client.request :get, uri
    end
    
    it "closes the response body if the request's method was HEAD" do
      Hatetepe::Request.any_instance.stub :response => response
      response.body.should_receive :close_write
      client.request :head, uri
    end
    
    it "returns the response" do
      Hatetepe::Request.any_instance.stub :response => response
      client.request(:get, uri).should equal(response)
    end
  end
  
  describe "#stop" do
    before do
      response.stub :body => stub("body")
      client.stub :requests => [request,
                                stub("another_request", :response => response)]
      client.stub :close_connection
    end
    
    it "waits for the last request to complete and then stops" do
      EM::Synchrony.should_receive(:sync).with(client.requests.last) { response }
      EM::Synchrony.should_receive(:sync).with response.body
      client.should_receive :close_connection
      client.stop
    end
  end
  
  describe "#wrap_body(body)" do
    let(:body) { stub "body" }
    
    it "doesn't modify a body that responds to #each" do
      body.stub :each
      client.wrap_body(body).should equal(body)
    end
    
    it "makes a body that responds to #read enumerable" do
      body.stub :read => stub("#read")
      client.wrap_body(body).should == [body.read]
    end
    
    it "makes other bodies enumerable" do
      client.wrap_body(body).should == [body]
    end
    
    it "makes an empty body enumerable" do
      client.wrap_body(nil).should == []
    end
  end
  
  describe ".start(config)" do
    let(:config) { {:host => "0.0.0.0", :port => 1234} }
    let(:client) { stub "client" }
    
    it "starts an EventMachine connection and returns it" do
      EM.should_receive(:connect).with(config[:host], config[:port],
                                       Hatetepe::Client, config) { client }
      Hatetepe::Client.start(config).should equal(client)
    end
  end
  
  describe ".request(verb, uri, headers, body)" do
    let(:client) { stub "client" }
    
    before do
      Hatetepe::Client.stub :start => client
      client.stub :request => response, :stop => nil
    end
    
    it "starts a client" do
      Hatetepe::Client.should_receive(:start).with :host => parsed_uri.host,
                                                   :port => parsed_uri.port
      Hatetepe::Client.request :get, uri
    end
    
    it "feeds the request into the client and returns the response" do
      client.should_receive(:request).with(:get, parsed_uri.request_uri,
                                           headers, body) { response }
      Hatetepe::Client.request(:get, uri, headers, body).should equal(response)
    end
    
    it "stops the client when the response has finished" do
      client.should_receive :stop
      Hatetepe::Client.request :get, uri
    end
  end
  
  [:get, :head, :post, :put, :delete,
   :options, :trace, :connect].each do |verb|
     describe "##{verb}(uri, headers, body)" do
       it "delegates to #request" do
         client.should_receive(:request).with(verb, uri, headers, body) { response }
         client.send(verb, uri, headers, body).should equal(response)
       end
     end
     
     describe ".#{verb}(uri, headers, body)" do
       let(:client) { Hatetepe::Client }
       
       it "delegates to .request" do
         client.should_receive(:request).with(verb, uri, headers, body) { response }
         client.send(verb, uri, headers, body).should equal(response)
       end
     end
   end
end

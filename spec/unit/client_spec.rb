require "spec_helper"
require "hatetepe/client"

describe Hatetepe::Client do
  let(:client) do
    Hatetepe::Client.allocate.tap {|c| c.send :initialize, config }
  end
  let(:config) { stub "config" }
  
  let(:request) { stub "request", :response => nil, :to_a => request_as_array }
  let(:request_as_array) { stub "request_as_array" }
  let(:response) { stub "response" }
  
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
      client.app.should be_a(Hatetepe::Client::Pipeline)
      client.app.app.should == client.method(:send_request)
    end
  end
  
  describe "#post_init" do
    it "wires the builder and parser" do
      client.post_init
      client.builder.on_write[0].should == client.method(:send_data)
      client.parser.on_response[0].should == client.method(:receive_response)
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
      client.should_receive :stop!
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
      client.pending_response[id] = stub("entry")
    end
    
    it "succeeds the pending response list entry of the first request without a response" do
      client.pending_response[id].should_receive(:succeed).with response
      client.receive_response response
    end
  end
  
  describe "#<<(request)" do
    it ""
  end
  
  describe "#request(verb, uri, headers, body)"
  
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
      client.should_receive :stop!
      client.stop
    end
  end
  
  describe "#stop!" do
    it "closes the connection" do
      client.should_receive :close_connection
      client.stop!
    end
  end
  
  describe ".start(config)" do
    it ""
  end
  
  describe ".request(verb, uri, headers, body)"
  
  [:get, :head, :post, :put, :delete,
   :options, :trace, :connect].each do |verb|
     describe "##{verb}(uri, headers, body)" do
       it ""
     end
     
     describe ".#{verb}(uri, headers, body)" do
       it ""
     end
   end
end

require "spec_helper"
require "hatetepe/client"

describe Hatetepe::Client::Pipeline do
  let(:app) { stub "app", :call => nil }
  let(:pipeline) { Hatetepe::Client::Pipeline.new app }
  
  describe "#initialize(app)" do
    it "sets the app" do
      pipeline.app.should equal(app)
    end
  end
  
  let(:requests) {
    [stub("previous_request"), stub("request")]
  }
  let(:lock) { stub "lock" }
  let(:pending) { {requests.first.object_id => lock} }
  let(:client) do
    stub "client", :requests => requests, :pending_transmission => pending
  end
  let(:response) { stub "response" }
  
  before do
    requests.last.stub :connection => client
    EM::Synchrony.stub :sync
  end
  
  describe "#call(request)" do
    it "waits until the previous request has been transmitted" do
      EM::Synchrony.should_receive(:sync).with lock
      pipeline.call requests.last
    end
    
    it "calls the app" do
      app.should_receive(:call).with(requests.last) { response }
      pipeline.call(requests.last).should equal(response)
    end
  end
end

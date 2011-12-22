require "spec_helper"
require "hatetepe/server"

describe Hatetepe::Server::App do
  let(:inner_app) { stub "inner app", :call => response }
  let(:app) { Hatetepe::Server::App.new inner_app }
  let(:env) {
    {
      "stream.start" => proc {},
      "stream.send" => proc {},
      "stream.close" => proc {},
      "hatetepe.connection" => Struct.new(:config).new({})
    }
  }
  
  let(:status) { 123 }
  let(:headers) { stub "headers" }
  let(:body) { [stub("chunk#1"), stub("chunk#2")] }
  let(:response) { [status, headers, body] }
  
  context "#initialize(inner_app)" do
    it "keeps the inner app" do
      Hatetepe::Server::App.new(inner_app).app.should equal(inner_app)
    end
  end
  
  context "#call(env)" do
    it "sets env[async.callback] before #call'ing inner_app" do
      app.call env
      
      app.should_receive(:postprocess) {|e, res|
        e.should equal(env)
        res.should equal(response)
      }
      env["async.callback"].call response
    end
    
    it "calls #postprocess with the return of inner_app#call(env)" do
      inner_app.stub :call => response
      app.should_receive(:postprocess) {|e, res|
        e.should equal(env)
        res.should equal(response)
      }
      
      app.call env
    end
    
    let(:error_response) {
      [500, {"Content-Type" => "text/html"}, ["Internal Server Error"]]
    }
    
    it "responds with 500 when catching an error" do
      inner_app.stub(:call) { raise }
      app.should_receive(:postprocess) {|e, res|
        res.should == error_response
      }
      
      app.call env
    end
    
    describe "if server's :env option is testing" do
      let(:error) { StandardError.new }
      
      before { env["hatetepe.connection"].config[:env] = "testing" }
      
      it "doesn't catch errors" do
        inner_app.stub(:call) { raise error }
        expect { app.call env }.to raise_error(error)
      end
    end
    
    let(:async_response) { [-1, {}, []] }
    
    it "catches :async for Thin compatibility" do
      inner_app.stub(:call) { throw :async }
      app.should_receive(:postprocess) {|e, res|
        res.should == async_response
      }
      
      app.call env
    end
  end
  
  context "#postprocess(env, response)" do
    it "does nothing if the response status is lighter than 0" do
      env["stream.start"].should_not_receive :call
      app.postprocess env, [-1]
    end
    
    it "starts the response stream" do
      env["stream.start"].should_receive(:call).with([status, headers])
      app.postprocess env, [status, headers, []]
    end
    
    it "streams the body" do
      body.should_receive :each do |&blk|
        blk.should equal(env["stream.send"])
      end
      app.postprocess env, [status, headers, body]
    end
    
    it "doesn't stream the body if it equals Rack::STREAMING" do
      body.should_not_receive :each
      app.postprocess env, [status, headers, Rack::STREAMING]
    end
    
    it "doesn't try to stream a body that isn't set" do
      body.should_not_receive :each
      app.postprocess env, [status, headers]
    end
    
    it "closes the response stream after streaming the body" do
      env["stream.close"].should_receive :call
      app.postprocess env, [status, headers, body]
    end
    
    it "closes the response even if streaming the body fails" do
      body.should_receive(:each).and_raise
      env["stream.close"].should_receive :call
      
      proc {
        app.postprocess env, [status, headers, body]
      }.should raise_error
    end
  end
end

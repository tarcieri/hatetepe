require "spec_helper"
require "hatetepe/app"

describe Hatetepe::App do
  let(:inner_app) { stub "inner app", :call => response }
  let(:app) { Hatetepe::App.new inner_app }
  let(:env) {
    {
      "stream.start" => stub("stream.start", :call => nil),
      "stream.send" => stub("stream.send", :call => nil),
      "stream.close" => stub("stream.close", :call => nil)
    }
  }
  
  let(:status) { 123 }
  let(:headers) { stub "headers" }
  let(:body) { [stub("chunk#1"), stub("chunk#2")] }
  let(:response) { [status, headers, body] }
  
  context "#initialize(inner_app)" do
    it "keeps the inner app" do
      Hatetepe::App.new(inner_app).app.should equal(inner_app)
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
    
    it "calls env[async.callback] with the return of inner_app#call(env)" do
      inner_app.stub :call => response
      app.should_receive(:postprocess) {|e, res|
        e.should equal(env)
        res.should equal(response)
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
      env["stream.send"].should_receive(:call).with(body[0])
      env["stream.send"].should_receive(:call).with(body[1])
      app.postprocess env, [status, headers, body]
    end
    
    it "doesn't stream the body if it equals Rack::STREAMING" do
      env["stream.send"].should_not_receive :call
      app.postprocess env, [status, headers, Rack::STREAMING]
    end
    
    it "closes the response stream after streaming the body" do
      env["stream.close"].should_receive :call
      app.postprocess env, [status, headers, body]
    end
  end
end
require "spec_helper"
require "hatetepe/proxy"

describe Hatetepe::Proxy do
  let(:app) { stub "app" }
  
  describe "#initialize(app)" do
    it "sets the app" do
      Hatetepe::Proxy.new(app).app.should equal(app)
    end
  end
  
  let(:proxy) { Hatetepe::Proxy.new app }
  let(:target) { stub "target" }
  let(:env) { {} }
  let(:client) { stub "client", :<< => nil }
  
  describe "#call(env)" do
    it "sets env[proxy.start]" do
      app.stub :call do |env|
        env["proxy.start"].should respond_to(:call)
      end
      proxy.call env
    end
    
    let(:response) { stub "response" }
    
    it "calls the app" do
      app.should_receive(:call).with(env) { response }
      proxy.call(env).should equal(response)
    end
    
    describe "env[proxy.start]" do
      it "forwards to #start" do
        proxy.should_receive(:start).with(env, target, client)
        app.stub :call do |env|
          env["proxy.start"].call target, client
        end
        proxy.call env
      end
    end
  end
  
  describe "#start(env, target, client)" do
    let(:request) { stub "request" }
    let(:response) { stub "response" }
    let(:callback) { stub "async.callback", :call => nil }
    
    let(:host) { stub "host" }
    let(:port) { stub "port" }
    let(:target) { stub "target", :host => host, :port => port }
    
    before do
      URI.stub :parse => target
      
      request.stub :dup => request, :response => response
      request.extend EM::Deferrable
      env["hatetepe.request"] = request
      env["async.callback"] = callback
    end
    
    it "deletes env[proxy.start] from the env hash" do
      env.should_receive(:delete).with "proxy.start"
      Fiber.new { proxy.start env, target, client }.resume
    end
    
    it "defaults env[proxy.start_reverse] to env[async.callback]" do
      Fiber.new { proxy.start env, target, client }.resume
      env["proxy.start_reverse"].should equal(env["async.callback"])
    end

    it "defaults env[proxy.callback] to env[proxy.start_reverse]" do
      Fiber.new { proxy.start env, target, client }.resume
      env["proxy.callback"].should equal(env["proxy.start_reverse"])
    end
    
    let(:new_client) { stub "new client" }
    
    it "starts a client if none was passed" do
      Hatetepe::Client.stub :start do |config|
        config[:host].should equal(host)
        config[:port].should equal(port)
        new_client
      end
      new_client.should_receive(:<<).with request
      Fiber.new { proxy.start env, target, nil }.resume
    end
    
    it "doesn't stop a client that was passed" do
      client.should_not_receive :stop
      Fiber.new { proxy.start env, target, client }.resume
      request.succeed
    end
    
    it "it passes env[hatetepe.request] to the client" do
      client.should_receive(:<<).with env["hatetepe.request"]
      Fiber.new { proxy.start env, target, client }.resume
    end
    
    it "passes the response to env[async.callback]" do
      callback.should_receive(:call).with response
      Fiber.new { proxy.start env, target, client }.resume
      request.succeed
    end
    
    it "waits for the request to succeed" do
      succeeded = false
      callback.stub(:call) {|response| succeeded = true }
      
      Fiber.new { proxy.start env, target, client }.resume
      succeeded.should be_false
      
      request.succeed
      succeeded.should be_true
    end
  end
end

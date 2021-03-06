require "spec_helper"
require "rack/handler/hatetepe"

describe Rack::Handler::Hatetepe do
  let(:app) { double "app" }
  let(:options) {
    {
      :Host => double("host"),
      :Port => double("port")
    }
  }
  let(:server) { double "server" }
  
  describe ".run(app, options) {|server| ... }" do
    before {
      EM.stub :epoll
      Signal.stub :trap
      Hatetepe::Server.stub :start
    }
    
    it "starts an Hatetepe server" do
      EM.should_receive :epoll
      EM.should_receive(:synchrony) {|&block|
        Hatetepe::Server.should_receive(:start) {|opts|
          opts[:host].should equal(options[:Host])
          opts[:port].should equal(options[:Port])
          opts[:app].should equal(app)
        }
        block.call
      }
      Rack::Handler::Hatetepe.run app, options
    end
    
    it "can be stopped by sending SIGTERM or SIGINT" do
      EM.should_receive(:synchrony) {|&block| block.call }
      
      trapped_signals = []
      Signal.should_receive(:trap).twice {|sig, &block|
        trapped_signals << sig
        EM.should_receive :stop
        block.call
      }
      Rack::Handler::Hatetepe.run app
      
      trapped_signals.should include("TERM")
      trapped_signals.should include("INT")
    end
  end
  
  describe ".run(app) {|server| ... }" do
    it "defaults Host to 0.0.0.0 and Port to 8080" do
      Hatetepe::Server.should_receive(:start) {|opts|
        opts[:host].should == "0.0.0.0"
        opts[:port].should == 8080
        EM.stop
      }
      Rack::Handler::Hatetepe.run app
    end
  end
end

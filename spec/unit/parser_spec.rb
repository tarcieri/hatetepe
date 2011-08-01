require "spec_helper"
require "hatetepe/parser"

describe Hatetepe::Parser do
  let(:parser) { Hatetepe::Parser.new }
  
  context "#initialize" do
    it "calls #reset" do
      Hatetepe::Parser.allocate.tap {|ins|
        ins.should_receive :reset
        ins.__send__ :initialize
      }
    end
  end
  
  context "#initialize {|instance| ... }" do
    it "yields the new instance" do
      instance = nil
      Hatetepe::Parser.new {|ins|
        instance = ins
      }.should equal(instance)
    end
    
    it "evals the block in its original context" do
      expected, actual = nil, nil
      Object.new.instance_eval {
        expected = self
        ::Hatetepe::Parser.new {|ins|
          actual = self
        }
      }
      
      actual.should equal(expected)
    end
  end
  
  context "#initialize {|| ... }" do
    it "evals the block in the new instance' context" do
      actual = nil
      expected = Hatetepe::Parser.new {
        actual = self
      }
      
      actual.should equal(expected)
    end
  end
  
  context "#reset" do
    before { parser << "GET / HTTP/1.1\r\n\r\n" }
    
    it "resets the message" do
      parser.reset
      parser.message.should be_nil
    end
    
    it "resets the state to :reset" do
      parser.reset
      parser.reset?.should be_true
    end
  end
  
  context "#<<(data)" do
    it "raises a ParserError if parsing fails" do
      expect {
        parser << "herp derp\r\n"
      }.to raise_error(Hatetepe::ParserError)
    end
  end
  
  let(:block) {
    stub("block").tap {|blk|
      blk.stub :to_proc => proc {|*args| blk.call *args }
    }
  }
  
  let(:do_request) {
    parser << "POST / HTTP/1.1\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Bar: baz\r\n"
    parser << "\r\n"
    parser << "6\r\n"
    parser << "Hello!\r\n"
    parser << "0\r\n"
    parser << "\r\n"
  }
  
  let(:do_response) {
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "\r\n"
  }
  
  context "#on_request {|request| ... }" do
    it "evals the block when a request line comes in" do
      block.should_receive(:call) {|request|
        request.should equal(parser.message)
        
        request.verb.should == "POST"
        request.uri.should == "/"
        request.http_version.should == "1.1"
        request.headers.should be_empty
      }
      
      parser.on_request &block
      do_request
    end
    
    it "changes the state to :request" do
      block.should_receive(:call) {
        parser.request?.should be_true
      }
      
      parser.on_request &block
      do_request
    end
  end
  
  context "#on_response {|response| ... }" do
    it "evals the block when a response line comes in" do
      block.should_receive(:call) {|response|
        response.should equal(parser.message)
        
        response.status.should == 200
        response.http_version.should == "1.1"
      }
      
      parser.on_response &block
      do_response
    end
    
    it "changes the state to :response" do
      block.should_receive(:call) {
        parser.response?.should be_true
      }
      
      parser.on_response &block
      do_response
    end
  end
  
  context "#on_headers {|headers| ... }" do
    it "evals the block when the headers are complete" do
      block.should_receive(:call) {|headers|
        headers.should equal(parser.message.headers)
        
        headers["Transfer-Encoding"].should == "chunked"
        headers["Bar"].should == "baz"
      }
      
      parser.on_headers &block
      do_request
    end
    
    it "changes the state to :headers" do
      block.should_receive(:call) {
        parser.headers?.should be_true
      }
      
      parser.on_headers &block
      do_request
    end
  end
  
  context "#on_body {|body| ... }" do
    it "evals the block when the body starts" do
      block.should_receive(:call) {|body|
        body.should equal(parser.message.body)
        
        body.should be_empty
      }
      
      parser.on_body &block
      do_request
      
      parser.message.body.length.should == 6
      parser.message.body.read.should == "Hello!"
    end
    
    it "changes the state to :body" do
      block.should_receive(:call) {
        parser.body?.should be_true
      }
      
      parser.on_body &block
      do_request
    end
  end
  
  context "#on_complete { ... }" do
    it "evals the block when the message is completely parsed" do
      block.should_receive(:call)
      
      parser.on_complete &block
      do_request
    end
    
    it "changes the state to :complete" do
      block.should_receive(:call) {
        parser.complete?.should be_true
      }
      
      parser.on_complete &block
      do_request
    end
    
    it "finishes the body" do
      parser.on_body {|body|
        body.should_receive :succeed
      }
      do_request
    end
  end
end

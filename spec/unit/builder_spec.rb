require "spec_helper"
require "hatetepe/builder"

describe Hatetepe::Builder do
  let(:builder) { Hatetepe::Builder.allocate }
  
  describe ".build {|builder| ... }"
  
  describe "#initialize" do
    it "resets the builder" do
      builder.should_receive :reset
      builder.send :initialize
    end
    
    it "initializes the on_complete, on_write, on_error hooks" do
      builder.send :initialize
      [:complete, :write, :error].each do |hook|
        builder.send(:"on_#{hook}").tap do |h|
          h.should be_an(Array)
          h.should be_empty
        end
      end
    end
  end
  
  describe "#initialize {|builder| ... }" do
    it "yields the builder" do
      arg = nil
      builder.send(:initialize) {|b| arg = b }
      arg.should equal(builder)
    end
  end
  
  [:complete, :write, :error].each do |hook|
    describe "#on_#{hook} {|*| ... }" do
      let(:block) { proc {} }
      before { builder.send :initialize }
      
      it "adds a hook block" do
        builder.send :"on_#{hook}", &block
        builder.send(:"on_#{hook}").should include(block)
      end
    end
  end
  
  describe "#writing_trailing_headers?" do
    it "returns true if the builder state is :ready" do
      builder.stub :state => :ready
      builder.ready?.should be_true
    end
    
    it "returns false otherwise" do
      builder.stub :state => :something
      builder.ready?.should be_false
    end
  end
  
  describe "#reset" do
    before { builder.send :reset }
    
    # XXX maybe don't test chunked flag
    it "resets the chunked flag and the builder state" do
      builder.chunked?.should be_nil
      builder.ready?.should be_true
    end
  end
  
  # XXX maybe test states and flags where they are being mutated
  describe "#ready?"
  describe "#writing_headers?"
  describe "#writing_body?"
  describe "#writing_trailing_headers?"
  describe "#chunked?"

  describe "#request(array)" do
    let(:req) { [:get, "/foo", {"Key" => "value"}, stub("body")] }
    
    before { builder.send :initialize }
    
    it "is a shortcut for #request_line, #headers, #body, #complete" do
      builder.should_receive(:request_line).with req[0], req[1]
      builder.should_receive(:headers).with req[2]
      builder.should_receive(:body).with req[3]
      builder.should_receive :complete
      builder.request req
    end
    
    it "doesn't require a body (fourth element)" do
      builder.should_receive(:request_line).with req[0], req[1]
      builder.should_receive(:headers).with req[2]
      builder.should_not_receive :body
      builder.request req[0..2]
    end
  end
    
  describe "#request_line(verb, uri, version)" do
    before { builder.send :initialize }
    
    it "writes a request line" do
      builder.should_receive(:write).with "GET /foo HTTP/1.0\r\n"
      builder.request_line :get, "/foo", "1.0"
    end
    
    it "changes the state to :writing_headers" do
      builder.request_line :get, "/foo"
      builder.state.should equal(:writing_headers)
    end
    
    it "defaults the version to 1.1" do
      builder.should_receive(:write).with "GET /foo HTTP/1.1\r\n"
      builder.request_line :get, "/foo"
    end
  end
  
  describe "#response_line(code, version)" do
    before { builder.send :initialize }
    
    it "writes a response line" do
      builder.should_receive(:write).with "HTTP/1.0 403 Forbidden\r\n"
      builder.response_line 403, "1.0"
    end
    
    it "changes the state to :writing_headers" do
      builder.response_line 403
      builder.state.should equal(:writing_headers)
    end
    
    it "default the version to 1.1" do
      builder.should_receive(:write).with "HTTP/1.1 403 Forbidden\r\n"
      builder.response_line 403
    end
    
    it "fails if there's no status message for code" do
      builder.should_receive :error
      builder.response_line 666
    end
  end
  
  describe "#response(array)" do
    let(:res) { [201, {"Key" => "value"}, stub("body")] }
    
    before { builder.send :initialize }
    
    it "is a shortcut for #response_line, #headers, #body, #complete" do
      builder.should_receive(:response_line).with res[0]
      builder.should_receive(:headers).with res[1]
      builder.should_receive(:body).with res[2]
      builder.should_receive :complete
      builder.response res
    end
    
    it "doesn't require a body (third element)" do
      builder.should_receive(:response_line).with res[0]
      builder.should_receive(:headers).with res[1]
      builder.should_not_receive :body
      builder.response res[0..1]
    end
  end
  
  describe "#header(name, value, charset)"
  describe "#headers(hash)"
  describe "#raw_header(header)"
  describe "#body(chunk)"
  describe "#complete"
  describe "#write(data)"
  describe "#error(message)" 
end

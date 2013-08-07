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
    let(:req) { [:get, "/foo", {"Key" => "value"}, double("body")] }
    
    before { builder.send :initialize }
    
    it "is a shortcut for #request_line, #headers, #body, #complete" do
      builder.should_receive(:request_line).with req[0], req[1], "1.1"
      builder.should_receive(:headers).with req[2]
      builder.should_receive(:body).with req[3]
      builder.should_receive :complete
      builder.request req
    end
    
    it "doesn't require a body (fourth element)" do
      builder.should_receive(:request_line).with req[0], req[1], "1.1"
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
    let(:res) { [201, {"Key" => "value"}, double("body")] }
    
    before { builder.send :initialize }
    
    it "is a shortcut for #response_line, #headers, #body, #complete" do
      builder.should_receive(:response_line).with res[0], "1.1"
      builder.should_receive(:headers).with res[1]
      builder.should_receive(:body).with res[2]
      builder.should_receive :complete
      builder.response res
    end
    
    it "doesn't require a body (third element)" do
      builder.should_receive(:response_line).with res[0], "1.1"
      builder.should_receive(:headers).with res[1]
      builder.should_not_receive :body
      builder.response res[0..1]
    end
  end
  
  describe "#headers(hash)" do
    it "writes each of the header pairs" do
      builder.should_receive(:header).with "Key", "value"
      builder.should_receive(:header).with "Key2", "value2"
      builder.headers "Key" => "value", "Key2" => "value2"
    end
  end
  
  describe "#header(name, value)" do
    it "writes the header pair" do
      builder.should_receive(:raw_header).with "Key: value"
      builder.header "Key", "value"
    end
  end
  
  describe "#raw_header(header)" do
    before do
      builder.send :initialize
      builder.response_line 200
    end
    
    it "writes the header line" do
      builder.should_receive(:write).with "Key: value\r\n"
      builder.raw_header "Key: value"
    end
    
    it "fails if no request or response line has been written" do
      builder.reset
      builder.should_receive :error
      builder.raw_header "Key: value"
    end
    
    it "fails if body already started" do
      builder.header "Content-Length", 5
      builder.body_chunk "asd"
      
      builder.should_receive :error
      builder.raw_header "Key: value"
    end
    
    it "writes trailing header if body already started and transfer is chunked" do
      builder.header "Transfer-Encoding", "chunked"
      builder.body_chunk "asd"
      
      builder.should_not_receive :error
      builder.should_receive(:write).with "0\r\n"
      builder.should_receive(:write).with "Key: value\r\n"
      builder.raw_header "Key: value"
      
      builder.state.should equal(:writing_trailing_headers)
    end
    
    it "sets the chunked flag" do
      builder.header "Transfer-Encoding", "chunked"
      builder.chunked?.should be_true
      
      builder.reset
      builder.response_line 200
      
      builder.header "Content-Length", "0"
      builder.chunked?.should be_false
    end
    
    it "doesn't set the chunked flag a second time" do
      builder.header "Transfer-Encoding", "chunked"
      builder.chunked?.should be_true
      
      builder.header "Content-Length", "0"
      builder.chunked?.should be_true
    end
  end
  
  describe "#body(#each)" do
    let(:body) { [double("chunk#1"), double("chunk#2")] }
    
    it "calls #body_chunk for each element" do
      builder.should_receive(:body_chunk).with body[0]
      builder.should_receive(:body_chunk).with body[1]
      builder.body body
    end
  end
  
  describe "#body_chunk(chunk)" do
    before do
      builder.send :initialize
      builder.response_line 200
    end
    
    it "fails if no request or response line has been written" do
      builder.reset
      builder.should_receive :error
      builder.body_chunk "asd"
    end
    
    it "fails if already writing trailing headers" do
      builder.body_chunk "asd"
      builder.header "Key", "value"
      builder.should_receive :error
      builder.body_chunk "asd"
    end
    
    it "assumes Transfer-Encoding: chunked if chunked flag isn't set" do
      builder.should_receive(:header).with "Transfer-Encoding", "chunked"
      builder.body_chunk "asd"
    end
    
    it "changes the state to :writing_body" do
      builder.body_chunk "asd"
      builder.state.should equal(:writing_body)
    end
    
    it "writes chunked body data" do
      builder.body_chunk ""
      builder.should_receive(:write).with "c\r\nasdfoobarbaz\r\n"
      builder.body_chunk "asdfoobarbaz"
    end
    
    it "writes empty chunked data" do
      builder.body_chunk ""
      builder.should_receive(:write).with "0\r\n\r\n"
      builder.body_chunk ""
    end
    
    it "writes plain body data" do
      builder.header "Content-Length", "12"
      builder.body_chunk ""
      builder.should_receive(:write).with "asdfoobarbaz"
      builder.body_chunk "asdfoobarbaz"
    end
    
    it "doesn't write empty plain data" do
      builder.header "Content-Length", "123"
      builder.body_chunk ""
      builder.should_not_receive :write
      builder.body_chunk ""
    end
  end
  
  describe "#complete" do
    before do
      builder.send :initialize
      builder.response_line 200
      builder.stub :body_chunk
    end
    
    it "does nothing if state is :ready" do
      builder.reset
      builder.should_not_receive :write
      builder.complete
    end
    
    it "sets Content-Length to 0 if no body has been sent and transfer is chunked" do
      builder.should_receive(:header).with "Content-Length", "0"
      builder.complete
    end
    
    it "writes an empty body chunk" do
      builder.should_receive(:body_chunk).with ""
      builder.complete
    end
    
    let(:hook) { double "hook", :call => nil }
    
    it "calls the on_complete hooks" do
      builder.on_complete << hook
      hook.should_receive :call
      builder.complete
    end
    
    it "calls #reset" do
      builder.should_receive :reset
      builder.complete
    end
  end
  
  describe "#write(data)" do
    let(:hook) { double "hook" }
    let(:data) { double "data" }
    
    before { builder.send :initialize }
    
    it "calls the on_write hooks" do
      builder.on_write << hook
      hook.should_receive(:call).with data
      builder.write data
    end
  end
  
  describe "#error(message)" do
    let(:hook1) { double "hook#1" }
    let(:hook2) { double "hook#2" }
    let(:message) { "error! error!" }
    let(:exception) { double "exception" }
    
    before do
      builder.send :initialize
      builder.on_error << hook1 << hook2
    end
    
    it "calls the error hooks" do
      Hatetepe::BuilderError.stub :new => exception
      
      hook1.should_receive(:call).with exception
      hook2.should_receive(:call).with exception
      builder.error message
    end
    
    it "raises the exception if no hooks were added" do
      builder.on_error.clear
      proc { builder.error message }.should raise_error(Hatetepe::BuilderError, message)
    end
  end
end

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
  
  # XXX maybe test this where it's being mutated
  describe "#chunked?"
  
  describe "#reset" do
    before do
      builder.send :initialize
      builder.reset
    end
    
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
  
  describe "#request(verb, uri, version)"
  describe "#request(array)"
  describe "#response(code, version)"
  describe "#response(array)"
  describe "#header(name, value, charset)"
  describe "#headers(hash)"
  describe "#raw_header(header)"
  describe "#body(chunk)"
  describe "#complete"
  describe "#write(data)"
  describe "#error(message)" 
end

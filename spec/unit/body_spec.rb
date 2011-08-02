require "spec_helper"
require "hatetepe/body"

describe Hatetepe::Body do
  let(:body) { Hatetepe::Body.new }
  
  context "#initialize" do
    it "leaves the IO stream empty" do
      body.io.length.should be_zero
    end
  end
  
  context "#initialize(string)" do
    let(:body) { Hatetepe::Body.new "herp derp" }
    
    it "writes the passed string" do
      body.length.should equal(9)
      body.io.read.should == "herp derp"
    end
  end
  
  context "#sync" do
    let(:conn) { stub "conn", :paused? => true }
    
    it "resumes the source connection if any" do
      body.source = conn

      conn.should_receive :resume
      Fiber.new { body.succeed }.resume
      body.sync
    end
    
    it "forwards to EM::Synchrony.sync(body)" do
      EM::Synchrony.should_receive(:sync).with(body)
      body.sync
    end
  end
  
  context "#length" do
    let(:length) { stub "length" }
    
    it "forwards to io#length" do
      body.io.stub :length => length
      body.length.should equal(length)
    end
  end
  
  context "#empty?" do
    it "returns true if length is zero" do
      body.stub :length => 0
      body.empty?.should be_true
    end
    
    it "returns false if length is non-zero" do
      body.stub :length => 42
      body.empty?.should be_false
    end
  end
  
  context "#pos" do
    let(:pos) { stub "pos" }
    
    it "forwards to io#pos" do
      body.io.stub :pos => pos
      body.pos.should equal(pos)
    end
  end
  
  context "#rewind" do
    let(:rewind) { stub "rewind" }
    
    it "forwards to io#rewind" do
      body.io.stub :rewind => rewind
      body.rewind.should equal(rewind)
    end
  end
  
  context "#close_write" do
    it "forwards to io#close_write"
    it "succeeds the body"
  end
  
  context "#closed_write?" do
    it "forwards to io#closed_write?"
  end
  
  context "#each {|chunk| ... }" do
    it "yields each written chunk until the body succeeds"
  end
  
  context "#read(length, buffer)" do
    it "waits for the body to succeed"
    it "forwards to io#read"
  end
  
  context "#gets" do
    it "waits for the body to succeed"
    it "forwards to io#gets"
  end
  
  context "#write(chunk)" do
    it "forwards to io#write"
  end
  
  context "#<<(chunk)" do
    it "forwards to io#<<"
  end
end

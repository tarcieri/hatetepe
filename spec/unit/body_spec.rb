require "spec_helper"
require "hatetepe/body"

describe Hatetepe::Body do
  let(:body) { Hatetepe::Body.new }
  
  it "is deferrable" do
    body.should respond_to(:callback)
  end
  
  context "#initialize" do
    it "leaves the IO stream empty" do
      body.io.length.should be_zero
    end
  end
  
  context "#initialize(string)" do
    let(:body) { Hatetepe::Body.new "herp derp" }
    
    before { body.close_write }
    
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
      body.stub :sync
      body.io.stub :length => length
      
      body.length.should equal(length)
    end
    
    it "waits for the body to succeed" do
      succeeded = false
      Fiber.new {
        body.length
        succeeded = true
      }.resume
      
      succeeded.should be_false
      
      body.close_write
      succeeded.should be_true
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
    it "blocks and forwards to io#rewind" do
      body.should_receive(:sync).ordered
      body.io.should_receive(:rewind).ordered
      body.rewind
    end
  end
  
  context "#close_write" do
    it "forwards to io#close_write" do
      body.io.should_receive :close_write
      body.close_write
    end
    
    it "succeeds the body" do
      body.should_receive :succeed
      body.close_write
    end
  end
  
  context "#closed_write?" do
    it "forwards to io#closed_write?" do
      ret = stub("return")
      body.io.should_receive(:closed_write?) { ret }
      
      body.closed_write?.should equal(ret)
    end
  end
  
  context "#each {|chunk| ... }" do
    it "yields each written chunk until the body succeeds" do
      chunks = ["111", "222"]
      received, succeeded = [], false
      
      body.write chunks[0]
      Fiber.new {
        body.each {|chunk| received << chunk }
        succeeded = true
      }.resume
      received.should == chunks.values_at(0)
      succeeded.should be_false
      
      body.write chunks[1]
      received.should == chunks
      succeeded.should be_false
      
      body.succeed
      succeeded.should be_true
    end

    it "returns self" do
      Fiber.new { body.each {}.should == body }.resume
      body.succeed
    end

    describe "without a block" do
      let(:enumerator) { stub }

      before { body.stub(:to_enum).with(:each) { enumerator } }

      it "immediately returns an Enumerator" do
        Fiber.new { body.each.should == enumerator }.resume
          body.succeed
      end
    end
  end
  
  context "#read(length, buffer)" do
    it "waits for the body to succeed" do
      ret, read = nil, false
      
      Fiber.new { body.read; read = true }.resume
      read.should be_false
      
      body.succeed
      read.should be_true
    end
    
    it "forwards to io#read" do
      body.succeed
      args, ret = [stub("arg#1"), stub("arg#2")], stub("ret")

      body.io.should_receive(:read).with(*args) { ret }
      body.read(*args).should equal(ret)
    end
  end
  
  context "#gets" do
    it "waits for the body to succeed" do
      ret, read = nil, false
      
      Fiber.new { body.gets; read = true }.resume
      read.should be_false
      
      body.succeed
      read.should be_true
    end
    
    it "forwards to io#gets" do
      body.succeed
      ret = stub("ret")

      body.io.should_receive(:gets) { ret }
      body.gets.should equal(ret)
    end
  end
  
  context "#write(chunk)" do
    it "forwards to io#write" do
      arg, ret = stub("arg"), stub("ret")
      body.io.should_receive(:write).with(arg) { ret }
      
      body.write(arg).should equal(ret)
    end
  end
end

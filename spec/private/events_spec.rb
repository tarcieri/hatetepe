require "spec_helper"
require "hatetepe/events"

describe Hatetepe::Events do
  let(:klass) {
    Class.new {
      include Hatetepe::Events
      event :foo
    }
  }
  let(:obj) { klass.new }
  
  context "#event(name, *args)" do
    let(:args) { ["arg#1", "arg#2", "arg#3"] }
    let(:called) { [] }
    
    before {
      obj.on_foo {|*args| called << [:bar, args] }
      obj.on_foo {|*args| called << [:baz, args] }
    }
    
    it "calls the listeners" do
      obj.event :foo, *args
      called.should == [[:bar, args], [:baz, args]]
    end
  end
  
  context "#event!(name, *args)" do
    let(:args) { [:foo, "arg#1", "arg#2"] }
    
    it "forwards to #event" do
      obj.should_receive(:event).with(*args)
      obj.event! *args
    end
    
    it "changes the state to specified name" do
      obj.on_foo {
        obj.foo?.should be_true
      }
      obj.event! :foo
    end
  end
  
  context ".event(name, *more_names)" do
    before { klass.event :bar, :baz }
    
    it "adds #on_name method" do
      obj.should respond_to(:on_bar)
    end
    
    it "adds #name? method" do
      obj.should respond_to(:bar?)
    end
    
    it "calls itself for each additional name" do
      obj.should respond_to(:on_baz)
      obj.should respond_to(:baz?)
    end
  end
  
  context "#on_name {|*args| ... }" do
    let(:block) { proc {} }
    
    it "adds the block to the listener stack" do
      obj.on_foo &block
      obj.on_foo.should include(block)
    end
  end
  
  context "#on_name" do
    let(:blocks) { [proc {}, proc {}] }
    
    it "returns the listener stack" do
      obj.on_foo &blocks[0]
      obj.on_foo &blocks[1]
      
      obj.on_foo.should == blocks
    end
    
    it "returns an empty stack if no listeners have been added yet" do
      obj.on_foo.should be_empty
    end
  end
  
  context "#name?" do
    it "returns true if the state equals :name" do
      obj.stub :state => :foo
      obj.foo?.should be_true
    end
    
    it "returns false if the state doesn't equal :name" do
      obj.stub :state => :bar
      obj.foo?.should be_false
    end
  end
end

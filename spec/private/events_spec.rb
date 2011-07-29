require "spec_helper"
require "hatetepe/events"

describe Hatetepe::Events do
  let(:klass) { Class.new { include Hatetepe::Events } }
  let(:obj) { klass.new }
  
  context "#event(name, *args)" do
    let(:args) { ["arg#1", "arg#2", "arg#3"] }
    let(:called) { [] }
    
    before {
      klass.event :foo
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
    
    before { klass.event :foo }
    
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
    it "adds #on_name method"
    it "adds #name? method"
    it "calls itself for each additional name"
  end
end

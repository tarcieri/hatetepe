require "spec_helper"
require "hatetepe/connection"

describe Hatetepe::Connection do
  let :conn do
    Object.new.extend Hatetepe::Connection
  end
  
  let(:address) { "127.0.0.1" }
  let(:port) { 34450 }
  let(:peername) { Socket.pack_sockaddr_in(port, address) }

  before { conn.stub :get_peername => peername }
  
  describe "#remote_address" do
    it "returns the remote peer's address" do
      conn.remote_address.should == address
    end
  end
  
  describe "#remote_port" do
    it "returns the remote peer's port" do
      conn.remote_port.should == port
    end
  end
  
  describe "#close_connection" do
    before { EM::Connection.any_instance.stub :close_connection }
    
    it "sets the closed-by-self flag" do
      pending "How to test a call to super?"
      
      conn.close_connection
      conn.should be_closed
      conn.should be_closed_by_self
    end
    
    let(:arg) { stub "arg" }
    
    it "calls EM::Connection.close_connection" do
      pending "How to test a call to super?"
      
      EM::Connection.any_instance.should_receive(:close_connection).with arg
      conn.close_connection arg
    end
  end
  
  describe "#unbind" do
    it "sets the closed-by-remote flag" do
      conn.unbind(nil)
      conn.should be_closed
      conn.should be_closed_by_remote
    end
    
    it "doesn't overwrite an existing closed-by flag" do
      conn.stub :closed? => true
      conn.unbind(nil)
      conn.should be_closed
      conn.should_not be_closed_by_remote
    end
  end
end

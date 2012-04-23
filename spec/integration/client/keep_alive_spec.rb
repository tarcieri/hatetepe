require "hatetepe/cli"
require "hatetepe/client"
require "spec_helper"
require "stringio"
require "yaml"

describe Hatetepe::Client, "with Keep-Alive" do
  let :client do
    Hatetepe::Client.start :host => "127.0.0.1", :port => 30001
  end
  
  it "keeps the connection open"
  
  it "sends Connection: keep-alive"
  
  describe "and an obviously single request" do
    it "sends Connection: close"
    
    it "closes the connection immediately after the response"
  end
  
  it "closes the connection if the server tells it to"
end

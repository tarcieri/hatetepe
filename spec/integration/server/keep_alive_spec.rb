require "spec_helper"
require "hatetepe/client"
require "hatetepe/server"

describe Hatetepe::Server, "with Keep-Alive" do
  describe "and :timeout option" do
    it "times out the connection after the specified amount of time"
  end
  
  describe "and :timeout option set to 0" do
    it "keeps the connection open until the client closes it"
  end
  
  it "closes the connection if the client sends Connection: close"

  it "responds with Connection: keep-alive if the client also sent it"
  
  ["1.0", "0.9"].each do |version|
    describe "and an HTTP #{version} client" do
      it "closes the connection after one request" do
        pending "http_parser.rb doesn't parse HTTP/0.9" if version == "0.9"
      end

      it "doesn't close the connection if the client sent Connection: Keep-Alive"
    end
  end
end

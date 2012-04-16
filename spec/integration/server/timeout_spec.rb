require "spec_helper"
require "hatetepe/client"
require "hatetepe/server"

describe Hatetepe::Server do
  let :options do
    { host: "127.0.0.1", port: 3123 }
  end

  let :client do
    Hatetepe::Client.start(options.merge(timeout: 0))
  end

  it "times out after 5 seconds of connection inactivity" do
    # only verify that 5 seconds is the default
    Hatetepe::Server::CONFIG_DEFAULTS[:timeout].should == 5
  end

  describe "with :timeout option" do
    before do
      Hatetepe::Server.start(options.merge(timeout: 0.5))
    end

    it "times out after the specified amount of seconds" do
      client.should_not be_closed
      EM::Synchrony.sleep(0.45)
      client.should_not be_closed

      EM::Synchrony.sleep(0.1)
      client.should be_closed_by_remote
    end
  end

  describe "with :timeout set to 0" do
    before do
      Hatetepe::Server.start(options.merge(timeout: 0))
    end

    it "never times out" do
      client.should_not be_closed
      EM::Synchrony.sleep(0.55)
      client.should_not be_closed
    end
  end
end

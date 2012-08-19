require "spec_helper"
require "hatetepe/client"
require "hatetepe/server"

describe Hatetepe::Client do
  let :options do
    { host: "127.0.0.1", port: 3123 }
  end

  let :options2 do
    { host: "1.2.3.4",   port: 3123}
  end

  let :client do
    Hatetepe::Client.start(options)
  end

  before do
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
      pending "EventMachine timeouts are not available on JRuby"
    end

    Hatetepe::Server.start(options.merge(timeout: 0))
  end

  it "times out after 5 seconds of connection inactivity" do
    # only verify that 5 seconds is the default, but actually
    # use a smaller timeout to keep specs fast
    Hatetepe::Client::CONFIG_DEFAULTS[:timeout].should == 5
  end

  it "times out after 5 seconds trying to establish a connection" do
    # only verify that 5 seconds is the default, but actually
    # use a smaller timeout to keep specs fast
    Hatetepe::Client::CONFIG_DEFAULTS[:connect_timeout].should == 5
  end

  describe "with :timeout option" do
    let :client do
      Hatetepe::Client.start(options.merge(timeout: 0.5))
    end

    it "times out after n seconds of connection inactivity" do
      client.should_not be_closed
      EM::Synchrony.sleep(0.45)
      client.should_not be_closed

      EM::Synchrony.sleep(0.1)
      client.should     be_closed
      client.should     be_closed_by_timeout
      client.should_not be_closed_by_connect_timeout
    end
  end

  describe "with :timeout set to 0" do
    let :client do
      Hatetepe::Client.start(options.merge(timeout: 0))
    end

    it "never times out" do
      client.should_not be_closed
      EM::Synchrony.sleep(0.55)
      client.should_not be_closed
    end
  end

  describe "with :connect_timeout option" do
    let :client do
      Hatetepe::Client.start(options2.merge(connect_timeout: 0.5))
    end

    # this example fails if there's no network connection
    it "times out after n seconds trying to establish a connection" do
      client.should_not be_closed
      EM::Synchrony.sleep(0.45)
      client.should_not be_closed

      EM::Synchrony.sleep(0.1)
      client.should     be_closed
      client.should     be_closed_by_connect_timeout
      client.should_not be_closed_by_timeout
    end
  end

  describe "with :connect_timeout set to 0" do
    let :client do
      Hatetepe::Client.start(options2.merge(connect_timeout: 0))
    end

    # this example fails if there's no network connection
    it "never times out trying to establish a connection" do
      client.should_not be_closed
      EM::Synchrony.sleep(0.55)
      client.should_not be_closed
    end
  end
end

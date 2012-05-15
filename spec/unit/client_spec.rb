require "spec_helper"
require "hatetepe/client"

describe Hatetepe::Client do
  let :config do
    {
      :host => "127.0.0.1",
      :port => 4242
    }
  end

  let :client do
    client = Object.new.extend(Hatetepe::Client)
    client.stub(:send_data)
    client.stub(:comm_inactivity_timeout=)
    client.stub(:pending_connect_timeout=)
    client.stub(:send_request) { response }

    client.send(:initialize, config)
    client.post_init
    client
  end

  describe ".start" do
    it "starts a new client" do
      EM.should_receive(:connect).
         with(config[:host], config[:port], Hatetepe::Client, config).
         and_return(client)
      Hatetepe::Client.start(config).should equal(client)
    end
  end

  describe "#stop" do
    it "waits for all requests to finish and closes the connection" do
      client.should_receive(:wait).ordered
      client.should_receive(:stop!).ordered
      client.stop
    end
  end

  describe "#stop!" do
    it "closes the connection" do
      client.should_receive(:close_connection)
      client.stop!
    end
  end

  describe "#wait" do
    let :requests do
      [ Hatetepe::Request.new(:get, "/"), Hatetepe::Request.new(:post, "/") ]
    end

    before do
      client.unstub(:send_request)
      client << requests[0]
      client << requests[1]
    end

    it "waits for all requests to finish" do
      returned = false
      Fiber.new do
        client.wait
        returned = true
      end.resume

      returned.should be_false

      requests.each(&:succeed)
      returned.should be_true
    end
  end

  describe ".request"

  describe "#request"

  describe "#<<" do
    let :request do
      Hatetepe::Request.new :head, "/test"
    end

    describe "if the response is a success" do
      let(:response) { Hatetepe::Response.new(307) }

      it "succeeds the request" do
        request.should_receive(:succeed).with(response)
        client << request
      end
    end

    describe "if the response is a failure" do
      let(:response) { Hatetepe::Response.new(502) }

      it "fails the request" do
        request.should_receive(:fail).with(response)
        client << request
      end
    end

    describe "if there is no response" do
      let(:response) { nil }

      it "fails the request" do
        request.should_receive(:fail).with(nil)
        client << request
      end
    end
  end
end

describe Hatetepe::Client, "(EventMachine API)" do
  describe "#initialize"

  describe "#post_init"

  describe "#receive_data"

  describe "#unbind"
end

describe Hatetepe::Client, "(private API)" do
  describe "#send_request"

  describe "#receive_response"
end

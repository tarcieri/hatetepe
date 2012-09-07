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
    Object.new.tap do |client|
      client.extend(Hatetepe::Client)
      client.stub(:send_data)
      client.stub(:comm_inactivity_timeout=)
      client.stub(:pending_connect_timeout=)
      client.stub(:send_request) { response }

      client.send(:initialize, config)
      client.post_init
    end
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

  describe ".request" do
    let(:client)   { stub("client", request: res, stop: nil)  }
    let(:headers)  { stub("headers") }
    let(:body)     { stub("body") }
    let(:res)      { stub("response") }
    let(:response) { Hatetepe::Client.request(:put, "/test", headers, body) }

    before { Hatetepe::Client.stub(start: client) }

    it "it returns the response" do
      client.should_receive(:request).with(:put, URI("/test"), headers, body)
      response.should equal(res)
    end

    it "stops the client afterwards" do
      client.should_receive(:stop)
      response
    end
  end

  describe "#request" do
    let(:body)     { [ "Hello,", " world!" ]            }
    let(:headers)  { { "Content-Type" => "text/plain" } }
    let(:request)  { stub("request")                    }
    let(:response) { stub("response")                   }

    before do
      client.stub(:<<)
      Hatetepe::Request.stub(:new => request)
    end

    it "sends the request" do
      Hatetepe::Request.should_receive(:new) do |verb, uri, headers, body|
        verb.should                           eq(:head)
        uri.path.should                       eq("/test")
        uri.query.should                      eq("key=value")
        headers["Content-Type"].should        eq("text/plain")
        Enumerator.new(body).to_a.join.should eq("Hello, world!")

        request
      end

      client.should_receive(:<<).with(request)
      EM::Synchrony.should_receive(:sync).with(request)

      client.request(:head, "/test?key=value", headers, body)
    end

    it "returns the response" do
      EM::Synchrony.stub(:sync => response)
      client.request(:get, "/").should equal(response)
    end
  end

  describe "#request!" do
    subject do
      proc { client.request!(:get, "/") }
    end

    let(:status)   { 200 }
    let(:response) { stub("response", :status => status) }

    before do
      client.stub(:request).with(:get, "/", {}, []) { response }
    end

    it "forwards to #request" do
      subject.call.should eq(response)
    end

    describe "for a 4xx response" do
      let(:status) { 404 }

      it "raises a ClientError" do
        subject.should raise_error(Hatetepe::ClientError)
      end
    end

    describe "for a 5xx response" do
      let(:status) { 502 }

      it "raises a ServerError" do
        subject.should raise_error(Hatetepe::ServerError)
      end
    end

    describe "if no response could be received" do
      let(:status) { 502 }

      it "raises a ServerError" do
        subject.should raise_error(Hatetepe::ServerError)
      end
    end
  end

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
        request.should_receive(:fail).with(nil, client)
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

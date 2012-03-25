require "spec_helper"
require "hatetepe/client"

describe Hatetepe::Client, "(public API)" do
  describe ".start"

  describe "#stop"

  describe "#stop!"

  describe "#wait"

  describe ".request"

  describe "#request"

  describe "#<<" do
    let :config do
      {
        :host => "127.0.0.1",
        :port => 4242
      }
    end

    let :subject do
      client = Object.new.extend(Hatetepe::Client)
      client.stub(:send_data)
      client.send(:initialize, config)
      client.post_init
      client
    end

    let :request do
      Hatetepe::Request.new :head, "/test"
    end

    it "calls the app in a Fiber" do
      fiber = Fiber.current
      subject.app.should_receive :call do
        Fiber.current.should_not equal(fiber)
      end

      subject << request
    end

    it "fails the request if the response is a failure" do
      subject.app.stub :call => Hatetepe::Response.new(400)
      request.should_receive(:fail).with(subject.app.call)

      subject << request
    end

    it "fails the request if there is no response (yet)" do
      subject.app.stub :call => nil
      request.should_receive(:fail).with(nil)

      subject << request
    end

    it "succeeds the request if the response is a success" do
      subject.app.stub :call => Hatetepe::Response.new(303)
      request.should_receive(:succeed).with(subject.app.call)

      subject << request
    end
  end
end

describe Hatetepe::Client, "EventMachine API" do
  describe "#initialize"

  describe "#post_init"

  describe "#receive_data"

  describe "#unbind"
end

describe Hatetepe::Client, "private API" do
  describe "#send_request"

  describe "#receive_response"
end

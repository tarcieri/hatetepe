# -*- encoding: utf-8 -*-

require "spec_helper"
require "hatetepe/server"

describe Hatetepe::Server, "(public API)" do
  describe ".start(config, &app)" do
    it "starts a server that listens on the supplied interface and port"
    it "passes the config to incoming connections"
    it "uses the passed block as app if any was passed"
  end

  describe ".stop" do
    it "waits for all requests to finish"
    it "stops the server"
  end

  describe ".stop!" do
    it "immediately stops the server"
  end

  describe "config[:app].call(env)" do
    let :subject do
      Object.new.tap do |s|
        s.extend Hatetepe::Server
        s.stub({
          :config    => {
            :host => "127.0.5.1",
            :port => 3000,
            :app  => stub("app")
          },
          :send_data => nil
        })
        s.post_init
      end
    end

    let :app do
      subject.config[:app]
    end

    let :http_request do
      [
        "POST /foo/bar?key=value HTTP/1.1",
        "Host: themachine.local",
        "Content-Length: 13",
        "",
        "Hello, world!"
      ].join("\r\n")
    end

    let :http_response do
      [
        "HTTP/1.1 403 Forbidden",
        "Content-Type: text/plain",
        "Transfer-Encoding: chunked",
        "",
        "b",
        "Mmh, nöö.",
        "0",
        "",
        ""
      ].join("\r\n")
    end

    it "receives the Rack Env hash as parameter" do
      app.should_receive :call do |env|
        Rack::Lint.new(app).check_env(env)
        env["REQUEST_METHOD"].should  == "POST"
        env["REQUEST_URI"].should     == "/foo/bar?key=value"
        env["HTTP_HOST"].should       == "themachine.local"
        env["rack.input"].read.should == "Hello, world!"
        [ 200, {}, [] ]
      end

      subject.receive_data(http_request)
    end

    it "returns a response array that will be sent to the client" do
      app.should_receive :call do |env|
        [ 403, { "Content-Type" => "text/plain" }, [ "Mmh, nöö." ] ]
      end

      sent = ""
      subject.stub(:send_data) {|data| sent << data }

      subject.receive_data(http_request)
      sent.should == http_response
    end
  end
end

describe Hatetepe::Server, "(EventMachine/sermipublic API)" do
  describe "#initialize(config)"

  describe "#post_init"

  describe "#receive_data(data)"

  describe "#unbind(reason)"
end

describe Hatetepe::Server, "(private API)" do
  describe "#process_request(request)"

  describe "#send_response(response)"
end

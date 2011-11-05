require "spec_helper"
require "hatetepe/client"

describe Hatetepe::Client do
  let(:client) {
    Hatetepe::Client.allocate.tap {|c|
      c.send :initialize, config
      c.stub :send_data
      c.post_init
    }
  }
  let(:config) {
    {
      :host => stub("host", :to_s => "foohost"),
      :port => stub("port", :to_s => "12345")
    }
  }
  
  context ".start(config)" do
    it "attaches a socket to the EventMachine reactor" do
      EM.should_receive(:connect) {|host, port, klass, cfg|
        host.should equal(cfg[:host])
        port.should equal(cfg[:port])
        klass.should equal(Hatetepe::Client)
        cfg.should equal(config)
        client
      }
      Hatetepe::Client.start(config).should equal(client)
    end
  end
  
  context ".request(verb, uri, headers, body)" do
    let(:verb) { stub "verb" }
    let(:uri) { "http://foo.bar/baz?key=value" }
    let(:headers) { stub "headers", :[]= => nil, :[] => nil }
    let(:body) { stub "body" }
    
    before {
      Hatetepe::Client.stub(:start) { client }
    }
    
    it "starts a client" do
      Fiber.new {
        Hatetepe::Client.should_receive(:start) {|config|
          config[:port].should == URI.parse(uri).port
          config[:host].should == URI.parse(uri).host
          client
        }
        Hatetepe::Client.request "GET", uri
      }.resume
    end
    
    let(:user_agent) { stub "user agent" }
    
    it "sets an appropriate User-Agent header if there is none" do
      Fiber.new {
        client.should_receive(:<<) {|request|
          request.headers["User-Agent"].should == "hatetepe/#{Hatetepe::VERSION}"
        }
        Hatetepe::Client.request "GET", uri
        
        client.should_receive(:<<) {|request|
          request.headers["User-Agent"].should equal(user_agent)
        }
        Hatetepe::Client.request "GET", uri, "User-Agent" => user_agent
      }.resume
    end
    
    it "uses an empty, write-closed Body as default" do
      Fiber.new {
        client.should_receive(:<<) {|request|
          request.body.closed_write?.should be_true
          request.body.should be_empty
        }
        Hatetepe::Client.request verb, uri
      }.resume
    end
    
    it "sends the request" do
      Fiber.new {
        client.should_receive(:<<) {|request|
          request.verb.should equal(verb)
          request.uri.should == URI.parse(uri).request_uri
          request.headers.should equal(headers)
          request.body.should equal(body)
        }
        Hatetepe::Client.request verb, uri, headers, body
      }.resume
    end
    
    it "waits for the request to succeed" do
      request, succeeded = nil, false
      Fiber.new {
        client.should_receive(:<<) {|req| request = req }
        Hatetepe::Client.request verb, uri
        succeeded = true
      }.resume
      
      succeeded.should be_false
      request.succeed
      succeeded.should be_true
    end
  end
  
  [:get, :head].each {|verb|
    context ".#{verb}(uri, headers)" do
      let(:uri) { stub "uri" }
      let(:headers) { stub "headers" }
      let(:response) { stub "response" }
      
      it "forwards to .request('#{verb.to_s.upcase}')" do
        Hatetepe::Client.should_receive(:request) {|verb, urii, hedders|
          verb.should == verb.to_s.upcase
          urii.should equal(uri)
          hedders.should equal(headers)
          response
        }
        Hatetepe::Client.send(verb, uri, headers).should equal(response)
      end
    end
  }
  
  [:options, :post, :put, :delete, :trace, :connect].each {|verb|
    context ".#{verb}(uri, headers, body)" do
      let(:uri) { stub "uri" }
      let(:headers) { stub "headers" }
      let(:response) { stub "response" }
      let(:body) { stub "body" }
      
      it "forwards to .request('#{verb.to_s.upcase}')" do
        Hatetepe::Client.should_receive(:request) {|verb, urii, hedders, bodeh|
          verb.should == verb.to_s.upcase
          urii.should equal(uri)
          hedders.should equal(headers)
          bodeh.should equal(body)
          response
        }
        Hatetepe::Client.send(verb, uri, headers, body).should equal(response)
      end
    end
  }
  
  context "#initialize(config)" do
    let(:client) { Hatetepe::Client.allocate }
    
    it "sets the config" do
      client.send :initialize, config
      client.config.should equal(config)
    end
  end
  
  context "#post_init" do
    let(:client) {
      Hatetepe::Client.allocate.tap {|c|
        c.send :initialize, config
      }
    }
    let(:requests) {
      [true, nil, nil].map {|response|
        Hatetepe::Request.new("GET", "/").tap {|request|
          request.response = response
        }
      }
    }
    let(:response) { stub "response", :body => Hatetepe::Body.new }
    
    before {
      client.post_init
      client.requests.push *requests
    }
    
    context "'s on_response handler" do
      it "associates the response with a request" do
        client.parser.on_response[0].call response
        requests[1].response.should equal(response)
      end
    end
    
    context "'s on_headers handler" do
      it "succeeds the response's request" do
        requests[1].response = response
        requests[1].should_receive(:succeed).with response
        client.parser.on_headers[0].call
      end
    end
    
    context "'s on_write handler" do
      it "forwards to EM's send_data" do
        client.builder.on_write[0].should == client.method(:send_data)
      end
    end
  end
  
  context "#<<(request)" do
    let(:request) { Hatetepe::Request.new "GET", "/" }
    let(:builder) { client.builder }
    
    it "forces a new Host header" do
      builder.should_receive(:header) {|key, value|
        value.should == "foohost:12345"
      }
      client << request
    end
    
    it "adds the request to #requests" do
      client << request
      client.requests.last.should equal(request)
    end
    
    it "feeds the builder" do
      request.body.write "asdf"
      
      builder.should_receive(:request_line).with request.verb, request.uri
      builder.should_receive(:headers).with request.headers
      builder.should_receive(:body).with request.body
      builder.should_receive(:complete)
      
      client << request
    end
    
    it "wraps the builder feeding within a Fiber" do
      outer, inner = Fiber.current, nil
      builder.should_receive(:request_line) {
        inner = Fiber.current
      }
      
      builder.stub :headers
      builder.stub :body
      builder.should_receive(:complete) {
        inner.should equal(Fiber.current)
      }
      
      client << request
      outer.should_not equal(inner)
    end
  end
  
  context "#receive_data(data)" do
    let(:chunk) { stub "chunk" }
    
    it "feeds the parser" do
      client.parser.should_receive(:<<).with chunk
      client.receive_data chunk
    end
  end
  
  context "#stop" do
    it "closes the connection" do
      client.should_receive :close_connection
      client.stop
    end
  end
end

require "spec_helper"
require "hatetepe/cli"
require "hatetepe/server"
require "hatetepe/version"
require "rack/builder"

describe Hatetepe::CLI do
  let :rackup do
    [ proc {|*| }, {} ]
  end

  before do
    file = File.expand_path("config.ru")
    Rack::Builder.stub(:parse_file).with(file) { rackup }

    $stdout, $stderr = StringIO.new, StringIO.new
    @old_env         = ENV.delete("RACK_ENV")
  end
  
  after do
    $stdout, $stderr = STDOUT, STDERR
    ENV["RACK_ENV"]  = @old_env
  end

  describe "#version" do
    it "prints Hatetepe's version" do
      Hatetepe::CLI.start([ "version" ])
      $stdout.rewind
      $stdout.read.should include(Hatetepe::VERSION)
    end
  end

  describe "#start" do
    it "starts a server running the default configuration" do
      Hatetepe::Server.should_receive(:start) do |config|
        config[:host].should    == "127.0.0.1"
        config[:port].should    equal(3000)
        config[:timeout].should be_nil
        
        config[:app].should    equal(rackup[0])
        ENV["RACK_ENV"].should == "development"
      end
      Hatetepe::CLI.start([])
    end

    it "writes stuff to stderr" do
      Hatetepe::CLI.start([])
      $stderr.rewind
      $stderr.read.should include("config.ru", "127.0.0.1:3000", "development")
    end

    it "starts an EventMachine reactor" do
      EM.should_receive(:synchrony)
      Hatetepe::CLI.start([])
    end

    it "enables epoll" do
      EM.should_receive(:epoll)
      Hatetepe::CLI.start([])
    end

    it "doesn't overwrite RACK_ENV" do
      ENV["RACK_ENV"] = "foobar"
      Hatetepe::CLI.start([])
      ENV["RACK_ENV"].should == "foobar"
    end

    describe "with --bind option" do
      it "passes the :host option to Server.start" do
        Hatetepe::Server.should_receive(:start) do |config|
          config[:host].should == "127.0.5.1"
        end
        Hatetepe::CLI.start([ "--bind", "127.0.5.1" ])
      end
    end

    describe "with --port option" do
      it "passes the :port option to Server.start" do
        Hatetepe::Server.should_receive(:start) do |config|
          config[:port].should == 5234
        end
        Hatetepe::CLI.start([ "--port", "5234" ])
      end
    end

    describe "with --timeout option" do
      it "passes the :timeout option to Server.start" do
        Hatetepe::Server.should_receive(:start) do |config|
          config[:timeout].should == 123.4
        end
        Hatetepe::CLI.start([ "--timeout", "123.4" ])
      end
    end

    describe "with --rackup option" do
      it "boots from the specified RackUp file" do
        file = File.expand_path("./other_config.ru")
        Rack::Builder.should_receive(:parse_file).with(file) { rackup }
        Hatetepe::Server.should_receive(:start) do |config|
          config[:app].should equal(rackup[0])
        end
        Hatetepe::CLI.start([ "--rackup", "other_config.ru" ])
      end
    end

    describe "with --env option" do
      it "sets RACK_ENV to the specified value" do
        Hatetepe::CLI.start([ "--env", "production" ])
        ENV["RACK_ENV"].should == "production"
      end
    end
  end
end

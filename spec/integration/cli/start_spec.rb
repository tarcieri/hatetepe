require "spec_helper"
require "hatetepe/cli"
require "hatetepe/server"
require "rack/builder"

describe Hatetepe::CLI do
  before do
    $stderr = StringIO.new
  end
  
  after do
    $stderr = STDERR
  end

  describe "#start" do
    let :rackup do
      [ proc {|*| }, {} ]
    end

    before do
      Rack::Builder.should_receive(:parse_file) { rackup }
    end

    it "starts a server running the default configuration" do
      Hatetepe::Server.should_receive(:start) do |config|
        config[:host].should    == "127.0.0.1"
        config[:port].should    equal(3000)
        config[:timeout].should == 5
        
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
  end

  describe "with --bind option"

  describe "with --port option"

  describe "with --rackup option"

  describe "with --env option"

  describe "with --timeout option"
end

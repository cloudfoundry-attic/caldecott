# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), "spec_helper")
require "caldecott-client/client"
require "caldecott-client/tunnel/tunnel"
require "caldecott-client/tunnel/http_tunnel"

describe "Client HTTP Tunnel" do
  include Caldecott::Client::Test

  describe "#request" do
    it "attempts to retry timed out connections" do
      create_http_with_error(Timeout::Error)
      max_retries = Caldecott::Client::HttpTunnel::MAX_RETRIES
      test_request_retry_times(@tunnel, max_retries, [200])
    end

    it "attempts to retry connections that raise exceptions" do
      create_http_with_error(StandardError)
      max_retries = Caldecott::Client::HttpTunnel::MAX_RETRIES
      test_request_retry_times(@tunnel, max_retries, [200])
    end

    it "attempts to retry connections that don't return success codes" do
      create_http_with_response_code(400)
      max_retries = Caldecott::Client::HttpTunnel::MAX_RETRIES
      test_request_retry_times(@tunnel, max_retries, [200])
    end

    it "successfully connects when success code is returned" do
      create_http_with_response_code(400)
      expect { @tunnel.request(get_request, "", [400]) }.to_not raise_error
    end
  end

  describe "#start" do
    it "sets path in and path out" do
      create_http_with_response_code(200)
      @tunnel.start
      @tunnel.path_in.should == "/tunnels/123/in"
      @tunnel.path_out.should == "/tunnels/123/out"
    end
  end

  describe "#write" do
    it "immediately closes connections that receive HTTP 404 error" do
      create_http_with_response_code(200)
      @tunnel.start
      create_http_with_response_code(404)
      @tunnel.write("sent data")
      @tunnel.closed?.should be true
    end

    it "sends data and advance the sequence number" do
      create_http_with_response_code(200)
      @tunnel.start
      @tunnel.write_seq.should == 1
      @tunnel.write("sent data")
      @tunnel.write_seq.should == 2
    end
  end

  describe "#read" do
    it "immediately closes connections that receive HTTP 404 errors" do
      create_http_with_response_code(200)
      @tunnel.start
      create_http_with_response_code(404)
      @tunnel.read
      @tunnel.closed?.should be true
    end

    it "returns data and advance the sequence number" do
      create_http_with_response_code(200)
      @tunnel.start
      @tunnel.read_seq.should == 1
      @tunnel.read.should == "received data"
      @tunnel.read_seq.should == 2
    end
  end

  describe "#stop" do
    it "is closed" do
      create_http_with_response_code(200)
      @tunnel.start
      @tunnel.stop
      @tunnel.closed?.should be true
    end
  end
end

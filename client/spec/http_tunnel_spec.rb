# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), "spec_helper")
require "caldecott-client/client.rb"
require "caldecott-client/client/tunnel.rb"
require "caldecott-client/client/http_tunnel.rb"

describe "Client HTTP Tunnel" do
  include Caldecott::Client::Test

  before do
    @tunnel = Caldecott::Client::HttpTunnel.new("http://tunnel.cloudfoundry.com", {})
  end

  describe "#request" do
    it "should attempt to retry timed out connections" do
      http = create_http_with_error(Timeout::Error)
      max_retries = Caldecott::Client::HttpTunnel::MAX_RETRIES
      test_request_retry_times(@tunnel, http, max_retries, [200])
    end

    it "should attempt to retry connections that raise exceptions" do
      http = create_http_with_error(StandardError)
      max_retries = Caldecott::Client::HttpTunnel::MAX_RETRIES
      test_request_retry_times(@tunnel, http, max_retries, [200])
    end

    it "should attempt to retry connections that don't return success codes" do
      http = create_http_with_response_code(400)
      max_retries = Caldecott::Client::HttpTunnel::MAX_RETRIES
      test_request_retry_times(@tunnel, http, max_retries, [200])
    end

    it "should successfully connect when success code is returned" do
      http = create_http_with_response_code(400)
      http.should_receive(:request).once
      expect { @tunnel.request(mock_request, "", [400]) }.to_not raise_error
    end
  end

  describe "#start" do
    it "should set path in and path out" do
      create_http_with_response_code(200)
      @tunnel.start
      @tunnel.path_in.should == "/tunnels/123/in"
      @tunnel.path_out.should == "/tunnels/123/out"
    end
  end

  describe "#write" do
    it "should immediately close connections that receive HTTP 404 error" do
      create_http_with_response_code(200)
      @tunnel.start
      create_http_with_response_code(404)
      @tunnel.write("")
      @tunnel.closed?.should be true
    end

    it "should send data and advance the sequence number" do
      create_http_with_response_code(200)
      @tunnel.start
      @tunnel.write_seq.should == 1
      @tunnel.should_receive(:request).once { |arg1, arg2, arg3|
        arg1.should be kind_of(Net::HTTP::Put)
        arg1.body.should == "test"
        arg1.path == "/tunnels/123/in/1"
      }.and_return(mock_data_response(200))
      @tunnel.write("test")
      @tunnel.write_seq.should == 2
    end

    it "should not send data when closing" do
      # TODO: implement this
    end

    it "should not consume retries when already writing" do
      # TODO: implement this
    end
  end

  describe "#read" do
    it "should immediately close connections that receive HTTP 404 errors" do
      create_http_with_response_code(200)
      @tunnel.start
      create_http_with_response_code(404)
      @tunnel.read
      @tunnel.closed?.should be true
    end

    it "should return data and advance the sequence number" do
      create_http_with_response_code(200)
      @tunnel.start
      @tunnel.read_seq.should == 1
      @tunnel.should_receive(:request).once { |arg1, arg2, arg3|
        arg1.should be kind_of(Net::HTTP::Get)
        arg1.path == "/tunnels/123/out/1"
      }.and_return(mock_data_response(200))
      @tunnel.read.should == "this data came from tunnel"
      @tunnel.read_seq.should == 2
    end
  end

  describe "#stop" do
    # TODO: implement this
  end
end

# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), "spec_helper")
require "caldecott-client/tunnel/tunnel"
require "caldecott-client/tunnel/http_tunnel"

describe "Client Tunnel" do
  it "starts an http tunnel when given a http url" do
    Caldecott::Client::HttpTunnel.should_receive(:new)
    Caldecott::Client::Tunnel.for_url("http://tunnel.cloudfoundry.com/", {})
  end

  it "starts an https tunnel when given a https url" do
    Caldecott::Client::HttpTunnel.should_receive(:new)
    Caldecott::Client::Tunnel.for_url("https://tunnel.cloudfoundry.com/", {})
  end

  it "raises an error when given an invalid url" do
    expect { Caldecott::Client::Tunnel.for_url("wtf://tunnel.com/", {}) }.to raise_exception
  end
end

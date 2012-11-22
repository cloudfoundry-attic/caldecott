# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), "spec_helper")
require "caldecott-client/client/tunnel.rb"
require "caldecott-client/client/http_tunnel.rb"
require "caldecott-client/client/websocket_tunnel.rb"

describe "Client Tunnel" do
  it "should start an http tunnel when given a http url" do
    Caldecott::Client::HttpTunnel.should_receive(:new)
    Caldecott::Client::Tunnel.for_url("http://tunnel.cloudfoundry.com/", {})
  end

  it "should start an https tunnel when given a https url" do
    Caldecott::Client::HttpTunnel.should_receive(:new)
    Caldecott::Client::Tunnel.for_url("https://tunnel.cloudfoundry.com/", {})
  end

  it "should start a websocket tunnel when given a ws url" do
    pending "Web Socket support is not implemented yet"
  end

  it "should start a secure websocket tunnel when given a wss url" do
    pending "Web Socket support is not implemented yet"
  end

  it "should raise an error when given an invalid url" do
    lambda { Caldecott::Client::Tunnel.for_url("wtf://tunnel.com/", {}) }.should raise_exception
  end
end

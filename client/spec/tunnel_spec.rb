# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')
require 'caldecott-client/tunnel/tunnel'
require 'caldecott-client/tunnel/http_tunnel'
require 'caldecott-client/tunnel/websocket_tunnel'

describe 'Client Tunnel' do
  before do
    @log = Logger.new StringIO.new
    @host = 'foo'
    @port = 12345
    @auth_token = 'this_is_an_auth_token'
  end

  it 'should start an http tunnel when given a http url' do
    url = 'http://tunnel.com/'
    Caldecott::Client::HttpTunnel.should_receive(:new).once.with(@log, url, @host, @port, @auth_token)
    Caldecott::Client::Tunnel.start(@log, url, @host, @port, @auth_token)
  end

  it 'should start an https tunnel when given a https url' do
    url = 'https://tunnel.com/'
    Caldecott::Client::HttpTunnel.should_receive(:new).once.with(@log, url, @host, @port, @auth_token)
    Caldecott::Client::Tunnel.start(@log, url, @host, @port, @auth_token)
  end

  it 'should start a websocket tunnel when given a ws url' do
    url = 'ws://tunnel.com/'
    Caldecott::Client::WebSocketTunnel.should_receive(:new).once.with(@log, url, @host, @port, @auth_token)
    Caldecott::Client::Tunnel.start(@log, url, @host, @port, @auth_token)
  end

  it 'should start a secure websocket tunnel when given a wss url' do
    pending "full end-to-end wss testing hasn't been done yet"
  end

  it 'should raise an error when given an invalid url' do
    lambda { Caldecott::Client::Tunnel.start(@log, 'wtf://tunnel.com/', @host, @port, @auth_token) }.should raise_exception
  end
end

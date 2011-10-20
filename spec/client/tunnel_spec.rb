# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')
require 'caldecott/client/tunnel.rb'
require 'caldecott/client/http_tunnel.rb'
require 'caldecott/client/websocket_tunnel.rb'

describe 'Client Tunnel' do
  before do
    @log = Logger.new StringIO.new
    @host = 'foo'
    @port = 12345
  end

  # FIXME: we need an https and wss test

  it 'should start an http tunnel when given a http url' do
    url = 'http://tunnel.com/'
    Caldecott::Client::HttpTunnel.should_receive(:new).once.with(@log, url, @host, @port)
    Caldecott::Client::Tunnel.start(@log, url, @host, @port)
  end

  it 'should start a websocket tunnel when given a websocket url' do
    url = 'ws://tunnel.com/'
    Caldecott::Client::WebSocketTunnel.should_receive(:new).once.with(@log, url, @host, @port)
    Caldecott::Client::Tunnel.start(@log, url, @host, @port)
  end

  it 'should raise an error when given an invalid url' do
    lambda { Caldecott::Client::Tunnel.start(@log, 'wtf://tunnel.com/', @host, @port) }.should raise_exception
  end
end

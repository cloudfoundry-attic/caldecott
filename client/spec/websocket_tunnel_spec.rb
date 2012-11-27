# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')
require 'caldecott-client/tunnel/websocket_tunnel'

describe 'Client WebSocket Tunnel' do

  before do
    @log = Logger.new StringIO.new
    @host = 'foo'
    @port = 12345
    @base_url = 'ws://tunnel/'
    @auth_token = 'this_is_an_auth_token'

    @ws_request = mock(EM::HttpRequest)
    @ws_request.should_receive(:get).once.and_return(@ws_request)

    EM::HttpRequest.should_receive(:new).once.with("#{@base_url}/websocket/#{@host}/#{@port}").and_return(@ws_request)

    @tunnel = Caldecott::Client::WebSocketTunnel.new(@log, @base_url, @host, @port, @auth_token)
  end

  describe '#onopen' do
    it 'should register the onopen handler' do
      @ws_request.should_receive(:callback) { |*args, &blk| @ws_callback = blk }
      times_called = 0
      @tunnel.onopen { times_called += 1 }
      @ws_callback.call
      times_called.should == 1
    end
  end

  describe '#onclose' do
    it 'should register the onclose handler' do
      @ws_request.should_receive(:errback)    { |*args, &blk| @ws_errback    = blk }
      @ws_request.should_receive(:disconnect) { |*args, &blk| @ws_disconnect = blk }
      times_called = 0
      @tunnel.onclose { times_called += 1 }
      @ws_errback.call
      times_called.should == 1
      @ws_disconnect.call
      times_called.should == 2
    end
  end

  describe '#onreceive' do
    it 'should receive data from the websocket' do
      msg = "hi there for receive"
      @ws_request.should_receive(:stream) { |*args, &blk| @ws_stream = blk }
      received = nil
      @tunnel.onreceive { |data| received = data }
      @ws_stream.call Base64.encode64(msg)
      received.should == msg
    end
  end

  describe '#send_data' do
    it 'should send data to the websocket' do
      msg = "hi there for send"
      @ws_request.should_receive(:send).with(Base64.encode64(msg))
      @tunnel.send_data(msg)
    end
  end

  describe '#close' do
    it 'should close the websocket' do
      @ws_request.should_receive(:close_connection_after_writing)
      @tunnel.close
    end
  end

end

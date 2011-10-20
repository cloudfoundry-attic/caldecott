# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')
require 'caldecott/server/websocket_tunnel.rb'

describe 'Server Websocket' do
  describe 'Tunnel' do
    it 'should have the same run! interface as sinatra' do
      port = 4242
      tunnel = mock(Caldecott::Server::WebSocketTunnel)
      tunnel.should_receive(:start).with(port).and_return(tunnel)
      Caldecott::Server::WebSocketTunnel.should_receive(:new).and_return(tunnel)
      Caldecott::Server::WebSocketTunnel.run!(:port => port)
    end
  end

  describe 'Websocket interface' do
    before do
      @host = 'foobar'
      @port = 50000

      # FIXME: we need to be able to shut up the logger directly
      Caldecott::SessionLogger.stub(:new).and_return(Logger.new StringIO.new)

      @websocket = mock(EM::WebSocket)
      @websocket.should_receive(:onopen)    { |*args, &blk| @websocket_onopen     = blk }
      @websocket.should_receive(:onmessage) { |*args, &blk| @websocket_onmessage  = blk }
      @websocket.should_receive(:onclose)   { |*args, &blk| @websocket_onclose    = blk }
      @websocket.should_receive(:request).and_return('Path' => "/websocket/#{@host}/#{@port}")

      websocket_port = 40000
      EM::WebSocket.should_receive(:start).with(:host => '0.0.0.0', :port => websocket_port).and_yield(@websocket)

      @tunnel = Caldecott::Server::WebSocketTunnel.new
      @tunnel.start(websocket_port)

      @connection = mock(Caldecott::TcpConnection)
      @connection.should_receive(:onopen)    { |*args, &blk| @connection_onopen    = blk }
      @connection.should_receive(:onreceive) { |*args, &blk| @connection_onreceive = blk }
      @connection.should_receive(:onclose)   { |*args, &blk| @connection_onclose   = blk }

      EM.should_receive(:connect).once.with(@host, @port.to_s, Caldecott::TcpConnection).and_yield(@connection)

      @websocket_onopen.call
      @connection_onopen.call
    end

    it 'should send data to the websocket that it receives from the destination' do
      data = "this is some data from the destination"
      @websocket.should_receive(:send).with(Base64.encode64(data))
      @connection_onreceive.call(data)
    end

    it 'should send data to the destination that it receives from the websocket' do
      data = "this is some data from the client"
      @connection.should_receive(:send_data).with(data)
      @websocket_onmessage.call(Base64.encode64(data))
    end

    it 'should close the websocket when the destination socket closes' do
      @websocket.should_receive(:close_connection)
      @connection_onclose.call
    end

    it 'should close the destination socket when the websocket closes' do
      @connection.should_receive(:close_connection_after_writing)
      @websocket_onclose.call
    end
  end
end

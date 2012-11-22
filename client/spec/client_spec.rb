# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), "spec_helper")
require "caldecott-client/client"

describe "Caldecott Client" do
  before do
    @tunnel = mock("Tunnel")
    @tunnel.stub(:for_url)
    @tunnel.stub(:start)
    @tunnel.stub(:read).and_return("")
    @tunnel.stub(:write)
    @tunnel.stub(:stop) { @tunnel.stub(:closed?).and_return(true) }
    @tunnel.stub(:closed?).and_return(false)

    @conn = mock(Socket, :closed? => false)
    @conn.stub(:close){ @conn.stub(:closed?).and_return(true) }
  end

  it "raises an error if tunnel url is not provided" do
    expect { Caldecott::Client.start({}) }.to raise_error(Caldecott::InvalidTunnelUrl)
  end

  it "sends buffered data from tunnel to local server" do
    options = { :tun_url => "http://tunnel.cloudfoundry.com" }
    client = Caldecott::Client::CaldecottClient.new(options)
    @conn.stub(:sendmsg) { |arg| arg }
    @tunnel.stub(:read) do
      @tunnel.stop
      "test"
    end
    stub_const("Caldecott::Client::BUFFER_SIZE", 1)

    # Should receive all data split by 1 byte
    @conn.should_receive(:sendmsg).exactly(4).times.and_return("t", "e", "s", "t")
    r = Thread.new do
      client.read_from_tunnel(@tunnel, @conn)
    end
    r.join
  end

  it "sends data from local server to tunnel" do
    options = { :tun_url => "http://tunnel.cloudfoundry.com" }
    client = Caldecott::Client::CaldecottClient.new(options)
    @conn.stub(:recv_nonblock).and_return("test")
    @tunnel.should_receive(:write).with("test")
    w = Thread.new do
      client.write_to_tunnel(@tunnel, @conn)
    end
    client.close
    w.join
  end
end
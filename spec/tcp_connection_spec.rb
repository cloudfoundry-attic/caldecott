# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')
require 'caldecott/tcp_connection.rb'

describe 'tcp connection' do
  before do
    @times_called          = { :onopen => 0, :onreceive => 0, :onclose => 0 }
    @expected_times_called = { :onopen => 1, :onreceive => 0, :onclose => 0 }

    @conn = Caldecott::TcpConnection.new nil
    @conn.onopen    { @times_called[:onopen]    += 1 }
    @conn.onreceive { @times_called[:onreceive] += 1 }
    @conn.onclose   { @times_called[:onclose]   += 1 }

    @conn.post_init
  end

  def validate_times_called
    @times_called[:onopen].should    == @expected_times_called[:onopen]
    @times_called[:onreceive].should == @expected_times_called[:onreceive]
    @times_called[:onclose].should   == @expected_times_called[:onclose]
  end

  describe 'callbacks setup before the connection is established' do
    it 'should call onopen after the connection is initialized' do
      # we can't test sequence too explicitly.. currently EM calls post_init
      # right when the Connection#new is called, but that might not always
      # be the behavior.  We'll call it ourselves just to make sure it gets
      # called though.  (The implementation only calls the provided block in
      # either case.)
      validate_times_called
    end

    it 'should call receive_data when data is received' do
      validate_times_called
      @conn.receive_data "data"
      @expected_times_called[:onreceive] = 1
      validate_times_called
      @conn.receive_data "more data"
      @expected_times_called[:onreceive] = 2
      validate_times_called
    end

    it 'should call onclose when the connection is closed' do
      validate_times_called
      @conn.unbind
      @expected_times_called[:onclose] = 1
      validate_times_called
    end
  end
end

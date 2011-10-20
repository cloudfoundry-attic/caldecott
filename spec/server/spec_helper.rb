# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'test/unit'
require 'sinatra'
require 'sinatra/async/test'

require 'caldecott/server/http_tunnel.rb'
require 'caldecott/tcp_connection.rb'

module Caldecott
  module Test
    module Server
      def validate_tunnel_info(tunnel_info, host, port)
        [:path, :path_in, :path_out].each do |k|
          tunnel_info[k].should_not be_nil
          tunnel_info[k].length.should > 0
        end

        tunnel_info[:dst_host].should == host
        tunnel_info[:dst_port].should == port
        tunnel_info[:dst_connected].should == true
        tunnel_info[:seq_out].should >= 0
        tunnel_info[:seq_in].should >= 0
      end

      def simulate_tunnel_open
        request = mock(::Sinatra::Base)
        request.should_receive(:content_type).with(:json)
        request.should_receive(:status).with(201)
        request.should_receive(:body) { |body| @tunnel_info = JSON.parse(body, :symbolize_names => true) }
        simulate_connection_open_for { @tunnel.open(request) }
      end

      def simulate_connection_open_for
        @connection = mock(Caldecott::TcpConnection)
        @connection.should_receive(:onopen)    { |*args, &blk| @onopen    = blk }
        @connection.should_receive(:onreceive) { |*args, &blk| @onreceive = blk }
        @connection.should_receive(:onclose)   { |*args, &blk| @onclose   = blk }

        EM.should_receive(:connect).once.with(@host, @port, Caldecott::TcpConnection).and_yield(@connection)
        yield
        @onopen.call
      end

      def do_with_invalid_sequence(method, offset)
        response = mock(::Sinatra::Base)
        response.should_receive(:halt).with(400, instance_of(String)).and_raise
        lambda { @tunnel.send(method, response, @tunnel_info[:seq_out] + offset) }.should raise_exception
      end

      module SinatraTest
        class App < Caldecott::Server::HttpTunnel
          set :environment, :test
          def self.options
            self.settings
          end
        end

        def app
          App
        end
      end

    end
  end
end

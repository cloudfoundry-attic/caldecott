# Copyright (c) 2009-2011 VMware, Inc.

require "webmock/rspec"

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "caldecott-client"

module Caldecott
  module Client
    module Test
      def with_em_timeout(timeout = 2)
        EM.run do
          EM.add_timer(timeout) do
            @validate.call if @validate
            EM.stop
          end
          yield
        end
      end

      def tunnel_callbacks
        [:onopen, :onclose, :onreceive]
      end

      def setup_tunnel_callback(tunnel, callback, opts)
        tunnel.send(callback) do |*args|
          @times_called[callback] += 1
          opts[callback].call(*args) if opts[callback]
          EM.stop if opts["stop_".concat(callback.to_s).to_sym]
        end
      end

      def setup_tunnel_callbacks(tunnel, opts = {})
        tunnel_callbacks.each { |c| setup_tunnel_callback(tunnel, c, opts) }
      end

      def simulate_error_on_connect(opts)
        with_em_timeout do
          # unfortunately, to_return(bla).times(n) isn't working, so we can't test
          # recovering from errors
          @request = stub_request(:post, "#{@base_url}/tunnels")
          @request.to_return(:status => opts[:response_code]) if opts[:response_code]
          @request.to_raise(opts[:raise]) if opts[:raise]

          if opts[:raise]
            lambda { Caldecott::Client::HttpTunnel.new(@log, @base_url, @host, @port, @auth_token) }.should raise_exception
            @validate = lambda do
              @times_called[:onopen].should == 0
              @times_called[:onclose].should == 0
              # FIXME: this is questionable.  What exceptions can really be
              # returned here?  Should we be retrying?  At a minimum, we should
              # document the exception block in Tunnel#start
              a_request(:post, "#{@base_url}/tunnels").should have_been_made.once
            end
            EM.stop
          else
            tunnel = Caldecott::Client::HttpTunnel.new(@log, @base_url, @host, @port, @auth_token)
            setup_tunnel_callbacks tunnel, :stop_onclose => true

            @validate = lambda do
              @times_called[:onopen].should == 0
              @times_called[:onclose].should == 1
              a_request(:post, "#{@base_url}/tunnels").should have_been_made.times(Caldecott::Client::HttpTunnel::MAX_RETRIES)
            end
          end
        end
      end

      def simulate_successful_connect
        @path = "sometunnel"
        @path_out = "#{@path}/out"
        @path_in = "#{@path}/in"

        response_body = { :path     => @path,
                          :path_out => @path_out,
                          :path_in  => @path_in }.to_json

        stub_request(:post, "#{@base_url}/tunnels").to_return(:body => response_body)

        @writer = mock(Caldecott::Client::HttpTunnel::Writer)

        Caldecott::Client::HttpTunnel::Reader.should_receive(:new).with(@log, "#{@base_url}/#{@path_out}", instance_of(Caldecott::Client::HttpTunnel), @auth_token)
        Caldecott::Client::HttpTunnel::Writer.should_receive(:new).with(@log, "#{@base_url}/#{@path_in}", instance_of(Caldecott::Client::HttpTunnel), @auth_token).and_return(@writer)
        Caldecott::Client::HttpTunnel.new(@log, @base_url, @host, @port, @auth_token)
      end

      def simulate_error_on_delete(opts)
        with_em_timeout do
          @request = stub_request(:delete, "#{@base_url}/#{@path}")
          @request.to_return(:status => opts[:response_code]) if opts[:response_code]

          EM.next_tick { @tunnel.close }
          @validate = lambda do
            @times_called[:onclose].should == 1
            a_request(:delete, "#{@base_url}/#{@path}").should have_been_made.times(Caldecott::Client::HttpTunnel::MAX_RETRIES)
          end
        end
      end

      def simulate_error_on_get(opts)
        with_em_timeout do
          @conn.should_receive(:trigger_on_close) { EM.stop }
          @request = stub_request(:get, "#{@uri}/1")
          @request.to_return(:status => opts[:response_code]) if opts[:response_code]
          reader = Caldecott::Client::HttpTunnel::Reader.new(@log, @uri, @conn, @auth_token)

          @validate = lambda do
            requests_expected = opts[:requests_expected]
            requests_expected ||= Caldecott::Client::HttpTunnel::MAX_RETRIES
            a_request(:get, "#{@uri}/1").should have_been_made.times(requests_expected)
          end
        end
      end

      def simulate_error_on_put(opts)
        with_em_timeout do
          data = 'some data to send via the writer'
          @conn.should_receive(:trigger_on_close) { EM.stop }
          @request = stub_request(:put, "#{@uri}/1")
          @request.to_return(:status => opts[:response_code]) if opts[:response_code]
          writer = Caldecott::Client::HttpTunnel::Writer.new(@log, @uri, @conn, @auth_token)
          EM.next_tick { writer.send_data data }

          @validate = lambda do
            requests_expected = opts[:requests_expected]
            requests_expected ||= Caldecott::Client::HttpTunnel::MAX_RETRIES
            a_request(:put, "#{@uri}/1").should have_been_made.times(requests_expected)
          end
        end
      end

    end
  end
end

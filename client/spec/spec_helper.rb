# Copyright (c) 2009-2011 VMware, Inc.

require "webmock/rspec"

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "caldecott-client"

TUNNEL_URL = "http://tunnel.cloudfoundry.com"

RSpec.configure do |rspec|
  rspec.before(:each) do
    Caldecott.logger = Logger.new(StringIO.new)
    @tunnel = Caldecott::Client::HttpTunnel.new(TUNNEL_URL, {})
  end
end

module Caldecott
  module Client
    module Test
      def create_http_with_response_code(code)
        path_info = {
            "path" => "/tunnels/123",
            "path_in" => "/tunnels/123/in",
            "path_out" => "/tunnels/123/out"
        }
        tunnel_path = /#{TUNNEL_URL}\/tunnels\/*/

        stub_request(:get, TUNNEL_URL).to_return(:status => code)

        stub_request(:get, tunnel_path).
            to_return(:body => "received data", :status => code)

        stub_request(:put, tunnel_path).with(:body => "sent data").
            to_return(:status => code)

        stub_request(:delete, tunnel_path).to_return(:status => code)

        stub_request(:post, TUNNEL_URL + "/tunnels").
            to_return(:body => JSON.generate(path_info), :status => code)
      end

      def create_http_with_error(error)
        stub_request(:any, TUNNEL_URL).to_raise(error)
      end

      def get_request
        Net::HTTP::Get.new(TUNNEL_URL)
      end

      def test_request_retry_times(tunnel, times, success_codes)
        begin
          tunnel.request(get_request, "testing request", success_codes)
        rescue Caldecott::ServerError # Failed to connect retry times
        end
        assert_requested(:get, TUNNEL_URL, :times => times)
      end
    end
  end
end
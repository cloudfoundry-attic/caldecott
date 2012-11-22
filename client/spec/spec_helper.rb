# Copyright (c) 2009-2011 VMware, Inc.

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

module Caldecott
  module Client
    module Test
      def create_http_with_response_code(code)
        http = mock("Net:HTTP")
        http.stub(:use_ssl=)

        http.stub(:request).and_return(mock_tunnel_response(code))

        Net::HTTP.stub(:new).and_return(http)

        http
      end

      def create_http_with_error(error)
        http = mock("Net:HTTP")
        http.stub(:use_ssl=)

        Net::HTTP.stub(:new).and_return(http)
        http.stub(:request).and_raise(error)

        http
      end

      def mock_request
        req = mock("Net::HTTPRequest")
        req.stub(:[]=)
        req
      end

      def mock_tunnel_response(code)
        resp = mock("Net::HTTPResponse")
        resp.stub(:code).and_return(code)
        path_info = {
            "path" => "/tunnels/123",
            "path_in" => "/tunnels/123/in",
            "path_out" => "/tunnels/123/out"
        }
        resp.stub(:body).and_return(JSON.generate(path_info))
        resp
      end

      def mock_data_response(code)
        resp = mock("Net::HTTPResponse")
        resp.stub(:code).and_return(code)
        resp.stub(:body).and_return("this data came from tunnel")
        resp
      end

      def test_request_retry_times(tunnel, http, times, success_codes)
        http.should_receive(:request).exactly(times).times
        req = mock_request
        begin
          tunnel.request(req, "testing request", success_codes)
        rescue Caldecott::ServerError # Failed to connect retry times
        end
      end
    end
  end
end

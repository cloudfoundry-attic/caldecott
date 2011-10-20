# Copyright (c) 2009-2011 VMware, Inc.

require 'addressable/uri'

module Caldecott
  module Client
    module Tunnel
      # Note: I wanted to do this with self#new but had issues
      # with getting send :initialize to figure out the right
      # number of arguments
      def self.start(logger, tun_url, dst_host, dst_port)
        case Addressable::URI.parse(tun_url).normalized_scheme
        when "http"
          HttpTunnel.new(logger, tun_url, dst_host, dst_port)
        when "ws"
          WebSocketTunnel.new(logger, tun_url, dst_host, dst_port)
        else
          raise "invalid url"
        end
      end
    end
  end
end

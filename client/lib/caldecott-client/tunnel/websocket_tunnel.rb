# Copyright (c) 2009-2011 VMware, Inc.

require 'em-http'

module Caldecott
  module Client
    class WebSocketTunnel
      def initialize(logger, url, dst_host, dst_port, auth_token)
        @ws = EM::HttpRequest.new("#{url}/websocket/#{dst_host}/#{dst_port}").get :timeout => 0
      end

      def onopen(&blk)
        @ws.callback { blk.call }
      end

      def onclose(&blk)
        @ws.errback { blk.call }
        @ws.disconnect { blk.call }
      end

      def onreceive(&blk)
        @ws.stream { |data| blk.call(Base64.decode64(data)) }
      end

      def send_data(data)
        # Um.. as soon as the em websocket object adds a better named
        # method for this, start using it.
        @ws.send(Base64.encode64(data))
      end

      def close
        @ws.close_connection_after_writing
      end
    end
  end
end

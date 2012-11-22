# Copyright (c) 2009-2011 VMware, Inc.

require 'em-websocket'
require 'base64'

module Caldecott
  module Server
    class WebSocketTunnel

      # quack like sinatra
      def self.run!(opts)
        WebSocketTunnel.new.start(opts[:port])
      end

      def start(port)
        EM::WebSocket.start(:host => "0.0.0.0", :port => port) do |ws|
          log = SessionLogger::new("server", STDOUT)
          dst_conn = nil

          ws.onopen do
            log.debug "tunnel connected"
            slash, tunnel, host, port = ws.request['Path'].split('/')

            EM::connect(host, port, TcpConnection) do |d|
              dst_conn = d

              dst_conn.onopen do
                log.debug "target connected"
              end

              dst_conn.onreceive do |data|
                log.debug("t <- d #{data.length}")
                ws.send(Base64.encode64(data))
              end

              dst_conn.onclose do
                log.debug "target disconnected"
                ws.close_connection
              end
            end
          end

          ws.onmessage do |msg|
            decoded = Base64.decode64(msg)
            log.debug("t -> d #{decoded.length}")
            dst_conn.send_data(decoded)
          end

          ws.onclose do
            log.debug "tunnel disconnected"
            dst_conn.close_connection_after_writing if dst_conn
          end
        end
      end
    end
  end
end

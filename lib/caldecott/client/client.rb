# Copyright (c) 2009-2011 VMware, Inc.

require 'eventmachine'

module Caldecott
  module Client
    def self.sanitize_url(tun_url)
      tun_url = tun_url =~ /(http|https|ws).*/i ? tun_url : "https://#{tun_url}"
    end

    def self.start(opts)
      local_port = opts[:local_port]
      tun_url    = opts[:tun_url]
      dst_host   = opts[:dst_host]
      dst_port   = opts[:dst_port]
      log_file   = opts[:log_file]
      log_level  = opts[:log_level]
      auth_token = opts[:auth_token]

      trap("TERM") { stop }
      trap("INT") { stop }

      tun_url = sanitize_url(tun_url)

      EM.run do
        puts "Starting local server on port #{local_port} to #{tun_url}"
        EM.start_server("localhost", local_port, TcpConnection) do |conn|
          # avoid races between tunnel setup and incoming local data
          conn.pause

          log = SessionLogger.new("client", log_file)
          log.level = SessionLogger.severity_from_string(log_level)

          tun = nil

          conn.onopen do
            log.debug "local connected"
            tun = Tunnel.start(log, tun_url, dst_host, dst_port, auth_token)
          end

          tun.onopen do
            log.debug "tunnel connected"
            conn.resume
          end

          conn.onreceive do |data|
            log.debug "l -> t #{data.length}"
            tun.send_data(data)
          end

          tun.onreceive do |data|
            log.debug("l <- t #{data.length}")
            conn.send_data(data)
          end

          conn.onclose do
            log.debug "local closed"
            tun.close
          end

          tun.onclose do
            log.debug "tunnel closed"
            conn.close_connection_after_writing
          end
        end
      end
    end

    def self.stop
      puts "Caldecott shutting down"
      EM.stop
    end
  end
end

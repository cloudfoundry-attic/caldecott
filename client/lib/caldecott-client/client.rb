# Copyright (c) 2009-2011 VMware, Inc.

require 'eventmachine'
require "logger"

$:.unshift(File.join(File.dirname(__FILE__), "tunnel"))

require "tunnel"
require "http_tunnel"

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

      @quiet = opts[:quiet]

      trap("TERM") { stop }
      trap("INT") { stop }

      tun_url = sanitize_url(tun_url)

      EM.run do
        unless @quiet
          puts "Starting local server on port #{local_port} to #{tun_url}"
        end

        EM.start_server("0.0.0.0", local_port, TcpConnection) do |conn|
          # avoid races between tunnel setup and incoming local data
          conn.pause

          log = Logger.new(log_file)
          log.level = Logger.const_get(log_level)

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
      puts "Caldecott shutting down" unless @quiet
      EM.stop
    end
  end
end

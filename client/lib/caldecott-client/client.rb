# Copyright (c) 2009-2011 VMware, Inc.

require "socket"
require "logger"

$:.unshift(File.join(File.dirname(__FILE__), "tunnel"))

require "tunnel"
require "http_tunnel"

module Caldecott

  class NotImplemented < StandardError; end
  class InvalidTunnelUrl < StandardError; end
  class ServerError < StandardError; end
  class ClientError < StandardError; end

  class << self
    attr_accessor :logger

    def init
      @logger = Logger.new(STDOUT)
    end
  end

  init

  module Client

    BUFFER_SIZE = 1024 * 1024 # 1Mb
    SOCKET_TIMEOUT = 30000 # 30s

    # This is how it's currently used by VMC:
    # Caldecott::Client.start(
    #   :local_port => local_port,
    #   :tun_url => tunnel_url,
    #   :dst_host => conn_info['hostname'],
    #   :dst_port => conn_info['port'],
    #   :log_file => STDOUT,
    #   :log_level => ENV["VMC_TUNNEL_DEBUG"] || "ERROR",
    #   :auth_token => auth,
    #   :quiet => true
    # )
    def self.start(options)
      @client = CaldecottClient.new(options)
      @client.start
    end

    def self.stop
      @client.close if @client
    end

    class CaldecottClient

      def initialize(options)
        raise InvalidTunnelUrl, "Tunnel URL is required" unless options[:tun_url]

        if options[:log_file]
          Caldecott.logger = Logger.new(options[:log_file])
        end

        Caldecott.logger.level = logger_severity_from_string(options[:log_level])

        @logger = Caldecott.logger

        @local_port = options[:local_port] || 20000

        @tunnel_url = sanitize_url(options[:tun_url])

        @tunnel_options = {
            :dst_host => options[:dst_host],
            :dst_port => options[:dst_port],
            :token => options[:auth_token]
        }

        @closed = false
      end

      def close
        @closed = true
      end

      def closed?
        @closed
      end

      def start
        @logger.info("Starting the tunnel on port #{@local_port}...")
        server = TCPServer.new("127.0.0.1", @local_port)
        @logger.info("Tunnel started")

        loop do
          # server.accept is blocking until request is received
          Thread.new(server.accept) do |conn|
            @logger.info("Connection accepted on #{@local_port}...")

            tunnel = create_tunnel
            tunnel.start

            w = Thread.new do
              write_to_tunnel(tunnel, conn)
            end

            r = Thread.new do
              read_from_tunnel(tunnel, conn)
            end

            r.join
            w.join

            @logger.info("Closing tunnel")
            conn.close
            tunnel.stop

            break if closed?
          end
        end

        server.close
      end

      def create_tunnel
        Tunnel.for_url(@tunnel_url, @tunnel_options)
      end

      def read_from_tunnel(tunnel, conn)
        in_buf = ""
        loop do
          in_buf << tunnel.read unless tunnel.closed?

          if in_buf.size > 0
            n_sent = conn.sendmsg(in_buf.slice!(0, BUFFER_SIZE))
            @logger.debug("l <- t: #{n_sent}, buf: #{in_buf.size}")
          end

          break if ( tunnel.closed? && in_buf.size < 1 ) || conn.closed? || closed?

          sleep(0.01) # minimize CPU usage and allow some data to buffer
        end
      end

      def write_to_tunnel(tunnel, conn)
        loop do
          begin
            out_data = conn.recv_nonblock(BUFFER_SIZE)
            if out_data.bytesize > 0
              @logger.debug("l -> t: #{out_data.size}")
              tunnel.write(out_data)
            end
          rescue Errno::EWOULDBLOCK
            # It's OK
          end

          break if tunnel.closed? || conn.closed? || closed?

          sleep(0.01) # minimize CPU usage and allow some data to buffer
        end
      end

      private

      def sanitize_url(tun_url)
        tun_url = tun_url.strip.downcase
        tun_url =~ /(http|https|ws).*/i ? tun_url : "https://#{tun_url}"
      end

      def logger_severity_from_string(str)
        case str.to_s.upcase
        when "DEBUG"
          Logger::DEBUG
        when "INFO"
          Logger::INFO
        when "WARN"
          Logger::WARN
        when "ERROR"
          Logger::ERROR
        when "FATAL"
          Logger::FATAL
        when "UNKNOWN"
          Logger::UNKNOWN
        else
          Logger::ERROR
        end
      end

    end
  end
end

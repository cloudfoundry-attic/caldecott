# Copyright (c) 2009-2011 VMware, Inc.

require "uri"
require "net/http"
require "json"

module Caldecott
  module Client
    class HttpTunnel < Tunnel
      MAX_RETRIES = 10

      attr_reader :path_in, :path_out, :write_seq, :read_seq

      def initialize(url, options)
        super

        begin
          @tun_url = URI.parse(url)
        rescue URI::Error
          raise ClientError, "Parsing tunnel URL failed"
        end

        @path_in = nil
        @path_out = nil
        @write_seq = nil
        @read_seq = nil
      end

      def start
        req = Net::HTTP::Post.new("/tunnels")
        req.body = JSON.generate(:host => dst_host, :port => dst_port)
        req["Content-Type"] = "application/json"

        resp = request(req, "creating tunnel remotely", [200, 201, 204])

        begin
          payload = JSON.parse(resp.body)
        rescue
          raise ClientError, "Parsing response data failed"
        end

        @tunnel_path = payload["path"]
        @path_in = payload["path_in"]
        @path_out = payload["path_out"]

        logger.info("Init success: tunnel_path=#{@tunnel_path}, " +
                        "path_in=#{@path_in}, path_out=#{@path_out}")
        @read_seq = 1
        @write_seq = 1
      end

      def write(data)
        if @path_in.nil? || @write_seq.nil?
          raise ClientError, "Cannot write, tunnel isn't ready"
        end

        req = Net::HTTP::Put.new(@path_in + "/#{@write_seq}")
        req.body = data
        logger.debug("Sending #{data.bytesize} bytes")

        resp = request(req, "sending data", [200, 202, 204, 404, 410])

        if [404, 410].include?(resp.code.to_i)
          close
          return
        end

        @write_seq += 1
      end

      def read
        if @path_out.nil? || @read_seq.nil?
          raise ClientError, "Cannot read, tunnel isn't ready"
        end

        req = Net::HTTP::Get.new(@path_out + "/#{@read_seq}")
        resp = request(req, "reading data", [200, 404, 410])

        @read_seq += 1

        if [404, 410].include?(resp.code.to_i)
          close
          return ""
        end

        resp.body
      rescue EOFError # HTTP quirk?
        ""
      end

      def stop
        return unless @tunnel_path # failed to start
        req = Net::HTTP::Delete.new(@tunnel_path)
        request(req, "closing remote tunnel", [200, 202, 204, 404])
        close
      end

      def request(req, msg, success_codes)
        req["Auth-Token"] = token
        retries = 0
        resp = nil

        loop do
          retries += 1
          logger.info("#{msg.capitalize} (retries=#{retries})")

          begin
            http = Net::HTTP.new(@tun_url.host, @tun_url.port)
            http.use_ssl = @tun_url.scheme == "https"

            resp = http.request(req)

            break if success_codes.include?(resp.code.to_i)

            logger.debug("Failed #{msg}: HTTP #{resp.code.to_i}")
          rescue Timeout::Error
            logger.error("Failed #{msg}: Timeout error")
          rescue StandardError => e # To satisfy current specs, do we need this really?
            logger.error("Failed #{msg}: #{e.message}")
          end

          if retries >= MAX_RETRIES
            raise ServerError, "Failed #{msg}"
          end
        end

        resp
      end

    end
  end
end

# Copyright (c) 2009-2011 VMware, Inc.

module Caldecott
  module Client
    class Tunnel

      def self.for_url(url, options)
        case url
          when /^https?/
            HttpTunnel.new(url, options)
          when /^ws/
            # TODO: implement
            raise NotImplemented, "Web Sockets support coming soon"
          else
            raise InvalidTunnelUrl,
                  "Invalid tunnel url: #{url}, only HTTP and WS schemas supported"
        end
      end

      attr_reader :url, :dst_host, :dst_port, :token, :logger

      def initialize(url, options)
        @url = url
        @dst_host = options[:dst_host]
        @dst_port = options[:dst_port]
        @token = options[:token]
        @logger = Caldecott.logger
        @closed = false
      end

      def close
        @closed = true
      end

      def closed?
        @closed
      end

      def start
        raise NotImplemented, "#start not implemented for #{self.class.name}"
      end

      def write(data)
        raise NotImplemented, "#write not implemented for #{self.class.name}"
      end

      def read
        raise NotImplemented, "#read not implemented for #{self.class.name}"
      end

      def stop
        raise NotImplemented, "#stop not implemented for #{self.class.name}"
      end
    end
  end
end

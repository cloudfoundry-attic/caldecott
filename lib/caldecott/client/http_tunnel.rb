# Copyright (c) 2009-2011 VMware, Inc.

require 'em-http'
require 'json'

module Caldecott
  module Client
    class HttpTunnel
      MAX_RETRIES = 10

      def initialize(logger, url, dst_host, dst_port)
        @log = logger
        @closing = false
        @retries = 0
        init_msg = ""

        # FIXME: why is this optional?
        if dst_host
          init_msg = { :host => dst_host, :port => dst_port }.to_json
        end

        start(url, init_msg)
      end

      def onopen(&blk)
        @onopen = blk
        @onopen.call if @opened
      end

      def onclose(&blk)
        @onclose = blk
        @onclose.call if @closed
      end

      def onreceive(&blk)
        @onreceive = blk
      end

      def send_data(data)
        @writer.send_data(data)
      end

      def close
        return if @closing or @closed
        @closing = true
        @writer.close if @writer
        @reader.close if @reader
        stop
      end

      def trigger_on_open
        @opened = true
        @onopen.call if @onopen
      end

      def trigger_on_close
        close
        @closed = true
        @onclose.call if @onclose
        @onclose = nil
      end

      def trigger_on_receive(data)
        @onreceive.call(data)
      end

      def start(base_uri, init_msg)
        if (@retries += 1) > MAX_RETRIES
          trigger_on_close
          return
        end

        begin
          parsed_uri = Addressable::URI.parse(base_uri)
          parsed_uri.path = '/tunnels'

          @log.debug "post #{parsed_uri.to_s}"
          req = EM::HttpRequest.new(parsed_uri.to_s).post :body => init_msg

          req.callback do
            @log.debug "post #{parsed_uri.to_s} #{req.response_header.status}"
            unless [200, 201, 204].include?(req.response_header.status)
              start(base_uri, init_msg)
            else
              @retries = 0
              resp = JSON.parse(req.response)

              parsed_uri.path = resp["path"]
              @tun_uri = parsed_uri.to_s

              parsed_uri.path = resp["path_out"]
              @reader = Reader.new(@log, parsed_uri.to_s, self)

              parsed_uri.path = resp["path_in"]
              @writer = Writer.new(@log, parsed_uri.to_s, self)
              trigger_on_open
            end
          end

          req.errback do
            @log.debug "post #{parsed_uri.to_s} error"
            start(base_uri, init_msg)
          end

        rescue Exception => e
          @log.error e
          trigger_on_close
          raise e
        end
      end

      def stop
        if (@retries += 1) > MAX_RETRIES
          trigger_on_close
          return
        end

        return if @tun_uri.nil?

        @log.debug "delete #{@tun_uri}"
        req = EM::HttpRequest.new("#{@tun_uri}").delete

        req.errback do
          @log.debug "delete #{@tun_uri} error"
          stop
        end

        req.callback do
          @log.debug "delete #{@tun_uri} #{req.response_header.status}"
          if [200, 202, 204, 404].include?(req.response_header.status)
            trigger_on_close
          else
            stop
          end
        end
      end

      class Reader
        def initialize(log, uri, conn)
          @log, @base_uri, @conn = log, uri, conn
          @retries = 0
          @closing = false
          start
        end

        def close
          @closing = true
        end

        def start(seq = 1)
          if (@retries += 1) > MAX_RETRIES
            @conn.trigger_on_close
            return
          end

          return if @closing
          uri = "#{@base_uri}/#{seq}"
          @log.debug "get #{uri}"
          req = EM::HttpRequest.new(uri).get :timeout => 0

          req.errback do
            @log.debug "get #{uri} error"
            start(seq)
          end

          req.callback do
            @log.debug "get #{uri} #{req.response_header.status}"
            case req.response_header.status
            when 200
              @conn.trigger_on_receive(req.response)
              @retries = 0
              start(seq + 1)
            when 404
              @conn.trigger_on_close
            else
              start(seq)
            end
          end
        end
      end

      class Writer
        def initialize(log, uri, conn)
          @log, @uri, @conn = log, uri, conn
          @retries = 0
          @seq, @write_buffer = 1, ""
          @closing = @writing = false
        end

        def send_data(data)
          @write_buffer << data
          send_data_buffered
        end

        def close
          @closing = true
        end

        def send_data_buffered
          if (@retries += 1) > MAX_RETRIES
            @conn.trigger_on_close
            return
          end

          return if @closing
          data, @write_buffer = @write_buffer, "" unless @writing

          @writing = true
          uri = "#{@uri}/#{@seq}"
          @log.debug "put #{uri}"
          req = EM::HttpRequest.new(uri).put :body => data

          req.errback do
            @log.debug "put #{uri} error"
            send_data_buffered
          end

          req.callback do
            @log.debug "put #{uri} #{req.response_header.status}"
            case req.response_header.status
            when 200, 202, 204
              @writing = false
              @seq += 1
              @retries = 0
              send_data_buffered unless @write_buffer.empty?
            when 404
              @conn.trigger_on_close
            else
              send_data_buffered
            end
          end
        end
      end
    end
  end
end

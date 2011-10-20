# Copyright (c) 2009-2011 VMware, Inc.

require 'rubygems'
require 'logger'
require 'sinatra'
require 'sinatra/async'
require 'json'
require 'uuidtools'
require 'eventmachine'
require 'caldecott/tcp_connection.rb'
require 'caldecott/session_logger.rb'

module Caldecott
  module Server
    class Tunnel
      attr_reader :tun_id, :log, :last_active_at
      DEFAULT_MAX_DATA_TO_BUFFER = 1 * 1024 * 1024 # 1MB

      def initialize(log, tunnels, host, port, max_data_to_buffer = DEFAULT_MAX_DATA_TO_BUFFER)
        @log, @tunnels, @host, @port = log, tunnels, host, port
        @tun_id = UUIDTools::UUID.random_create.to_s
        @data = @data_next = ""
        @seq_out = @seq_in = 0
        @max_data_to_buffer = max_data_to_buffer
        @last_active_at = Time.now
      end

      def open(resp)
        EM::connect(@host, @port, TcpConnection) do |dst_conn|
          @dst_conn = dst_conn

          @dst_conn.onopen do
            @log.debug "dst connected"
            @tunnels[@tun_id] = self
            resp.content_type :json
            resp.status 201
            resp.body safe_hash.to_json
          end

          @dst_conn.onreceive do |data|
            @log.debug "t <- d #{data.length}"
            @data_next << data
            trigger_reader
            @dst_conn.pause if @data_next.length > @max_data_to_buffer
          end

          @dst_conn.onclose do
            @log.debug "target disconnected"
            @dst_conn = nil
            trigger_reader
            @tunnels.delete(@tun_id) if @data_next.empty?
          end
        end
        @tunnel_created_at = Time.now
      end

      def delete
        @log.debug "target disconnected"
        if @dst_conn
          @dst_conn.close_connection_after_writing
        else
          @tunnels.delete(@tun_id)
        end
      end

      def get(resp, seq)
        @last_active_at = Time.now
        resp.halt(400, "invalid sequence #{seq} for server seq #{@seq_out}") unless (seq == @seq_out or seq == @seq_out + 1)
        if seq == @seq_out + 1
          @data, @data_next = @data_next, ""
          @seq_out = seq
        end

        if @data.empty?
          resp.halt(410, "destination socket closed\n") if @dst_conn.nil?
          @log.debug "get: waiting for data"
          @reader = EM.Callback do
            @data, @data_next = @data_next, ""
            resp.ahalt(410, "destination socket closed\n") if @data.empty?
            @log.debug "get: returning data (async)"
            resp.body @data
          end
        else
          @log.debug "get: returning data (immediate)"
          resp.body @data
          @dst_conn.resume
        end
      end

      def put(resp, seq)
        @last_active_at = Time.now
        resp.halt(400, "invalid sequence #{seq} for server seq #{@seq_in}") unless (seq == @seq_in or seq == @seq_in + 1)
        if seq == @seq_in
          resp.status 201
        else
          @seq_in = seq
          @log.debug "t -> d #{resp.request.body.length}"
          @dst_conn.send_data(resp.request.body.read)
          resp.status 202
        end
      end

      def trigger_reader
        return unless @reader
        reader = @reader
        @reader = nil
        reader.call
      end

      def safe_hash
        {
          :path => "/tunnels/#{@tun_id}",
          :path_in => "/tunnels/#{@tun_id}/in",
          :path_out => "/tunnels/#{@tun_id}/out",
          :dst_host => @host,
          :dst_port => @port,
          :dst_connected => @dst_conn.nil? == false,
          :seq_out => @seq_out,
          :seq_in => @seq_in
        }
      end

    end

    class HttpTunnel < Sinatra::Base
      register Sinatra::Async

      @@tunnels = {}

      def self.tunnels
        @@tunnels
      end

      # defaults are 1 hour of inactivity with sweeps every 5 minutes
      def self.start_timer(inactive_timeout = 3600, sweep_interval = 300)
        EventMachine::add_periodic_timer sweep_interval do
          # This is needed because there seems to have a bug on the
          # Connection#set_comm_inactivity_timeout (int overflow )
          # Look at eventmachine/ext/em.cpp 2289
          # It reaps the inactive connections
          #
          # We also can not seem to add our own timer per tunnel instance.
          # When we do, the ruby interpreter freaks out and starts throwing
          #
          # errors like:
          #    undefined method `cancel' for 57:Fixnum
          #
          # for code like the following during shutdown:
          #    @inactivity_timer.cancel if @inactivity_timer
          #    @inactivity_timer.cancel
          #    @inactivity_timer = nil
          @@tunnels.each do |id, t|
            t.delete if (Time.now - t.last_active_at) > inactive_timeout
          end
        end
      end

      def tunnel_from_id(tun_id)
        tun = @@tunnels[tun_id]
        not_found("tunnel #{tun_id} does not exist\n") unless tun
        tun.log.debug "#{request.request_method} #{request.url}"
        tun
      end

      before do
        not_found if env['HTTP_AUTH_TOKEN'] != settings.auth_token
      end

      get '/' do
        return "Caldecott Tunnel (HTTP Transport) #{VERSION}\n"
      end

      get '/tunnels' do
        content_type :json
        resp = @@tunnels.values.collect { |t| t.safe_hash }
        resp.to_json
      end

      apost '/tunnels' do
        log = SessionLogger.new("server", STDOUT)
        log.debug "#{request.request_method} #{request.url}"
        req = JSON.parse(request.body.read, :symbolize_names => true)
        Tunnel.new(log, @@tunnels, req[:host], req[:port]).open(self)
      end

      get '/tunnels/:tun' do |tun_id|
        log = SessionLogger.new("server", STDOUT)
        log.debug "#{request.request_method} #{request.url}"
        tun = tunnel_from_id(tun_id)
        tun.safe_hash.to_json
      end

      delete '/tunnels/:tun' do |tun_id|
        log = SessionLogger.new("server", STDOUT)
        log.debug "#{request.request_method} #{request.url}"
        tun = tunnel_from_id(tun_id)
        tun.delete
      end

      aget '/tunnels/:tun_id/out/:seq' do |tun_id, seq|
        tun = tunnel_from_id(tun_id)
        seq = seq.to_i
        tun.get(self, seq)
      end

      put '/tunnels/:tun_id/in/:seq' do |tun_id, seq|
        tun = tunnel_from_id(tun_id)
        seq = seq.to_i
        tun.put(self, seq)
      end
    end
  end
end

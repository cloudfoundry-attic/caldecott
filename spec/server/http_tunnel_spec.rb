# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe 'Server' do
  include Caldecott::Test::Server

  before do
    @log = Logger.new StringIO.new
    @host = "foobar"
    @port = 4242
    @max_data_to_buffer = 40000

    @start_time = Time.now
    @tunnels = Caldecott::Server::HttpTunnel.tunnels
    @tunnel = Caldecott::Server::Tunnel.new(@log, @tunnels, @host, @port, @max_data_to_buffer)

    # FIXME: we need to be able to shut up the logger directly
    Caldecott::SessionLogger.stub(:new).and_return(Logger.new StringIO.new)
  end

  after do
    @connection.should_receive(:close_connection_after_writing).at_most(:once) { @onclose.call } if @connection
    @tunnel.delete
  end

  describe 'HTTP Tunnel' do
    describe "when not connected yet" do
      it "should not add itself to the active tunnels" do
        @tunnels.length.should == 0
      end

      it "should have an initial activity time" do
        @tunnel.last_active_at.should > @start_time
      end
    end

    describe "when connected" do
      before do
        simulate_tunnel_open
      end

      it "should return connection info" do
        validate_tunnel_info(@tunnel_info, @host, @port)
      end

      it "should add itself to the active tunnels" do
        @tunnels.length.should == 1
      end

      it "should be removed from active tunnels when inactive" do
        EM.run do
          @tunnels.length.should == 1
          @connection.should_receive(:close_connection_after_writing).at_most(:once) { @onclose.call }

          # 3 seconds inactivity, 1 seconds sweeps
          Caldecott::Server::HttpTunnel.start_timer(2, 1)

          EM.add_timer(3) do
            @tunnels.length.should == 0
            EM.stop
          end
        end
      end

      describe "#get" do
        it "should return an error when asked to GET data for sequence < current_sequence" do
          do_with_invalid_sequence :get, -1
          do_with_invalid_sequence :get, -2
          do_with_invalid_sequence :get, -10
        end

        it "should return an error when asked to GET data for sequence > current_sequence + 1" do
          do_with_invalid_sequence :get, 2
          do_with_invalid_sequence :get, 3
          do_with_invalid_sequence :get, 10
        end

        it "should GET data asynchronously and synchronously" do
          data = "this is some data"

          # do a read before data has been received from the destination
          response = mock(Sinatra::Base)
          @tunnel.get(response, @tunnel_info[:seq_out])

          # now simulate data from the destionation
          response.should_receive(:body).with(data)
          @onreceive.call(data)

          # re-read the data.  Since we didn't advance the sequence number,
          # we should get the same data back. It should return right away.
          response2 = mock(Sinatra::Base)
          response2.should_receive(:body).with(data)
          @connection.should_receive(:resume).at_most(:once)
          @tunnel.get(response2, @tunnel_info[:seq_out])
        end

        it "should advance the GET sequence numbers by 1" do
          data1 = "this is some data"
          data2 = "even more data!"
          sequence = @tunnel_info[:seq_out]

          @onreceive.call(data1)

          # read from the current sequence number
          response = mock(Sinatra::Base)
          response.should_receive(:body).with(data1)
          @connection.should_receive(:resume).at_most(:once)
          @tunnel.get(response, sequence += 1)

          @onreceive.call(data2)

          # read from the next seqence number
          response2 = mock(Sinatra::Base)
          response2.should_receive(:body).with(data2)
          @connection.should_receive(:resume).at_most(:once)
          @tunnel.get(response2, sequence += 1)
        end

        it "should provide flow control" do
          sequence = @tunnel_info[:seq_out]
          data = 'A' * (@max_data_to_buffer - 2)
          @onreceive.call(data)

          # should not trigger flow controll still
          @onreceive.call("ab")

          # this one should (we are 1 character over)
          @connection.should_receive(:pause)
          @onreceive.call("c")

          # read 1 byte.  flow controll should not get turned off
          response = mock(Sinatra::Base)
          response.should_receive(:body).with(data + "abc")
          @connection.should_receive(:resume)
          @tunnel.get(response, sequence += 1)
        end

      end

      describe "#put" do
        it "should return an error when asked to PUT data for sequence < current_sequence" do
          do_with_invalid_sequence :put, -1
          do_with_invalid_sequence :put, -2
          do_with_invalid_sequence :put, -10
        end

        it "should return an error when asked to PUT data for sequence > current_sequence + 1" do
          do_with_invalid_sequence :put, 2
          do_with_invalid_sequence :put, 3
          do_with_invalid_sequence :put, 10
        end

        it "should be idempotent" do
          response = mock(Sinatra::Base)
          response.should_receive(:status).with(201)
          @tunnel.put(response, @tunnel_info[:seq_in])
        end

        it "should advance the PUT sequence numbers by 1" do
          sequence = @tunnel_info[:seq_out]

          ["first data", "second data"].each do |data|
            request_body = StringIO.new data

            request = mock(Sinatra::Base)
            request.should_receive(:body).at_least(:once).and_return(request_body)

            response = mock(Sinatra::Base)
            response.should_receive(:request).at_least(:once).and_return(request)
            response.should_receive(:status).with(202)

            @connection.should_receive(:send_data).with(data)
            @tunnel.put(response, sequence += 1)
          end
        end
      end

      describe "#delete" do
        it "should remote itself from the active tunnels" do
          @tunnels.length.should == 1
          @connection.should_receive(:close_connection_after_writing) { @onclose.call }
          @tunnel.delete
          @tunnels.length.should == 0
        end
      end

      describe "and then disconnected" do
        describe "#get" do
          it "should return an error when the destination closes while waiting for data" do
            # do a read before data has been received from the destination
            response = mock(Sinatra::Base)
            @tunnel.get(response, @tunnel_info[:seq_out])
            response.should_receive(:ahalt).with(410, instance_of(String)).and_raise
            lambda { @onclose.call }.should raise_exception
          end
        end

        describe "#delete" do
          it "should remove itself from the active tunnels" do
            @tunnels.length.should == 1
            @connection.should_receive(:close_connection_after_writing).at_most(:once) { @onclose.call }
            @tunnel.delete
            @tunnels.length.should == 0
          end
        end
      end
    end
  end

  describe "Sinatra endpoint" do
    include Test::Unit::Assertions
    include Rack::Test::Methods
    include Sinatra::Async::Test::Methods
    include Caldecott::Test::Server::SinatraTest

    it "should return banner via GET" do
      get '/'
      last_response.should be_ok
      last_response.body.should == "Caldecott Tunnel (HTTP Transport) #{Caldecott::VERSION}\n"
    end

    it "should respond to GET /tunnels" do
      get '/tunnels'
      last_response.should be_ok
      response = JSON.parse(last_response.body, :symbolize_names => true)
      response.length.should == 0
    end

    it "should forward POSTs to Tunnel" do
      Caldecott::Server::Tunnel.should_receive(:new).once.with(duck_type(:debug), @tunnels, @host, @port).and_return(@tunnel)
      simulate_connection_open_for do
        apost '/tunnels', { :host => @host, :port => @port }.to_json
      end
      em_async_continue
    end

    describe 'tunnel operations' do
      before do
        simulate_tunnel_open
      end

      it "should include the tunnel in GET /tunnels" do
        get '/tunnels'
        last_response.should be_ok
        response = JSON.parse(last_response.body, :symbolize_names => true)
        response.length.should == 1
        validate_tunnel_info(response[0], @host, @port)
      end

      it "should repond to GET /tunnel/:valid_id" do
        get @tunnel_info[:path]
        last_response.should be_ok
        response = JSON.parse(last_response.body, :symbolize_names => true)
        validate_tunnel_info(response, @host, @port)
      end

      it "should return a 404 for GET /tunnel/:invalid_id" do
        get "#{@tunnel_info[:path] + "nope"}"
        last_response.status.should == 404
      end

      it "should return a 400 for GET /tunnel (no id)" do
        get '/tunnels/'
        # FIXME: validate some reasonable error here rather then the stock
        # sinatra error
        last_response.status.should == 404
      end

      it "should forward a DELETE to the tunnel" do
        @connection.should_receive(:close_connection_after_writing).at_most(:once) { @onclose.call }
        delete @tunnel_info[:path]
        @tunnel.should_receive(:delete)
      end

      it "should return a 404 for DELETE /tunnel/:invalid_id" do
        delete "#{@tunnel_info[:path] + "nope"}"
        last_response.status.should == 404
      end

      it "should forward a PUT to the tunnel" do
        sequence = 502
        @tunnel.should_receive(:put).once.with(duck_type(:request), sequence)
        put "#{@tunnel_info[:path_in]}/#{sequence}", "some data"
      end

      it "should return a 404 for a PUT to an invalid tunnel" do
        put "#{@tunnel_info[:path_in] + "nope"}/#{@tunnel_info[:seq_in] + 1}", "data"
        last_response.status.should == 404
      end

      it "should forward a GET request to the tunnel" do
        sequence = 692
        @tunnel.should_receive(:get).once.with(duck_type(:response), sequence) { |response, sequence| response.body "data" }
        aget "#{@tunnel_info[:path_out]}/#{sequence}"
        em_async_continue
      end

      it "should return a 404 for a GET to an invalid tunnel" do
        # The get should return right away.  The async sinatra unit test
        # methods don't really allow for that use case and they throw an
        # exception, however, the response does come back and can be checked.
        lambda { aget "#{@tunnel_info[:path_out] + "nope"}/#{@tunnel_info[:seq_out] + 1}"}.should raise_error
        last_response.status.should == 404
      end
    end
  end
end

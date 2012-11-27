# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe 'Client HTTP Tunnel' do
  include Caldecott::Client::Test

  before do
    @log = Logger.new StringIO.new
    @host = 'foo'
    @port = 12345
    @base_url = 'http://caldecott.cloudfoundry.com'
    @times_called = {}
    @auth_token = "this_is_the_token"
    tunnel_callbacks.each { |c| @times_called[c] = 0 }
  end

  after do
    @validate.call if @validate
  end

  it 'should attempt to retry timed out connections' do
    with_em_timeout do
      stub_request(:post, "#{@base_url}/tunnels").to_timeout
      tunnel = Caldecott::Client::HttpTunnel.new(@log, @base_url, @host, @port, @auth_token)
      setup_tunnel_callbacks tunnel, :stop_onclose => true

      @validate = lambda do
        a_request(:post, "#{@base_url}/tunnels").should have_been_made.times(Caldecott::Client::HttpTunnel::MAX_RETRIES)
        @times_called[:onclose].should == 1
      end
    end
  end

  it 'should attempt to retry connections that receive HTTP 400 errors' do
    simulate_error_on_connect :response_code => 400
  end

  it 'should attempt to retry connections that receive HTTP 500 errors' do
    simulate_error_on_connect :response_code => 500
  end

  it 'should attempt to retry connections that raise exceptions' do
    simulate_error_on_connect :raise => StandardError
  end

  it 'should successfully connect' do
    with_em_timeout do
      tunnel = simulate_successful_connect
      setup_tunnel_callbacks tunnel, :stop_onopen => true
      @validate = lambda do
        @times_called[:onopen].should == 1
        @times_called[:onclose].should == 0
        a_request(:post, "#{@base_url}/tunnels").should have_been_made.once
      end
    end
  end

  describe '#onreceive' do
    it 'should register the onreceive handler and receive data' do
      with_em_timeout do
        data = "some data to receive"
        received = nil
        tunnel = simulate_successful_connect
        setup_tunnel_callbacks(tunnel,
                               :stop_onreceive => true,
                               :onreceive => lambda { |d| received = d })
        tunnel.trigger_on_receive data
        @validate = lambda do
          @times_called[:onopen].should == 1
          @times_called[:onclose].should == 0
          @times_called[:onreceive].should == 1
          received.should == data
          a_request(:post, "#{@base_url}/tunnels").should have_been_made.once
        end
      end
    end
  end

  describe '#send_data' do
    it 'should forward data to the writter' do
      with_em_timeout do
        data = "some data to send"
        tunnel = simulate_successful_connect
        setup_tunnel_callbacks tunnel
        EM.next_tick { tunnel.send_data data }
        @writer.should_receive(:send_data).with(data) { EM.stop }
      end
    end
  end

  describe '#close' do
    before do
      @tunnel = simulate_successful_connect
      setup_tunnel_callbacks @tunnel, :stop_onclose => true
      @writer.should_receive(:close)
    end

    it 'should attempt to retry timed out connections' do
      with_em_timeout do
        stub_request(:delete, "#{@base_url}/#{@path}").to_timeout
        EM.next_tick { @tunnel.close }

        @validate = lambda do
          a_request(:delete, "#{@base_url}/#{@path}").should have_been_made.times(Caldecott::Client::HttpTunnel::MAX_RETRIES)
          @times_called[:onclose].should == 1
        end
      end
    end

    it 'should attempt to retry deletes that receive HTTP 400 errors' do
      simulate_error_on_delete :response_code => 400
    end

    it 'should attempt to retry deletes that receive HTTP 500 errors' do
      simulate_error_on_delete :response_code => 500
    end

    it 'should successfully delete the tunnel' do
      with_em_timeout do
        stub_request(:delete, "#{@base_url}/#{@path}")
        EM.next_tick { @tunnel.close }
        @validate = lambda do
          @times_called[:onclose].should == 1
          a_request(:delete, "#{@base_url}/#{@path}").should have_been_made.once
        end
      end
    end
  end

  describe 'Reader' do
    before do
      @conn = mock(Caldecott::Client::HttpTunnel)
      @uri = "http://bla.com/some_tunnel_uri/in"
    end

    it 'should attempt to retry timed out connections' do
      with_em_timeout do
        @conn.should_receive(:trigger_on_close) { EM.stop }
        stub_request(:get, "#{@uri}/1").to_timeout
        reader = Caldecott::Client::HttpTunnel::Reader.new(@log, @uri, @conn, @auth_token)

        @validate = lambda do
          a_request(:get, "#{@uri}/1").should have_been_made.times(Caldecott::Client::HttpTunnel::MAX_RETRIES)
        end
      end
    end

    it 'should attempt to retry deletes that receive HTTP 400 errors' do
      simulate_error_on_get :response_code => 400
    end

    it 'should attempt to retry deletes that receive HTTP 500 errors' do
      simulate_error_on_get :response_code => 500
    end

    it 'should immediately close connections that receive HTTP 404 errors' do
      simulate_error_on_get :response_code => 404, :requests_expected => 1
    end

    it 'should return data and advance the sequence number' do
      with_em_timeout do
        reader = nil
        data = 'some data received by the reader'
        more_data = 'some more data received by the reader'
        @conn.should_receive(:trigger_on_receive).with(data).ordered
        @conn.should_receive(:trigger_on_receive).with(more_data).ordered do
          reader.close
          EM.stop
        end

        stub_request(:get, "#{@uri}/1").to_return(:status => 200, :body => data)
        stub_request(:get, "#{@uri}/2").to_return(:status => 200, :body => more_data)
        reader = Caldecott::Client::HttpTunnel::Reader.new(@log, @uri, @conn, @auth_token)
      end
    end
  end

  describe 'Writer' do
    before do
      @conn = mock(Caldecott::Client::HttpTunnel)
      @uri = "http://bla.com/some_tunnel_uri/out"
    end

    it 'should attempt to retry timed out connections' do
      with_em_timeout do
        data = 'some data to send via the writer'
        @conn.should_receive(:trigger_on_close) { EM.stop }
        stub_request(:put, "#{@uri}/1").to_timeout
        writer = Caldecott::Client::HttpTunnel::Writer.new(@log, @uri, @conn, @auth_token)
        EM.next_tick { writer.send_data data }

        @validate = lambda do
          a_request(:put, "#{@uri}/1").should have_been_made.times(Caldecott::Client::HttpTunnel::MAX_RETRIES)
        end
      end
    end

    it 'should attempt to retry deletes that receive HTTP 400 errors' do
      simulate_error_on_put :response_code => 400
    end

    it 'should attempt to retry deletes that receive HTTP 500 errors' do
      simulate_error_on_put :response_code => 500
    end

    it 'should immediately close connections that receive HTTP 404 errors' do
      simulate_error_on_put :response_code => 404, :requests_expected => 1
    end

    it 'should send data and advance the sequence number' do
      with_em_timeout do
        writer = nil
        data = 'some data sent by the writer'
        more_data = 'some more data sent by the writer'
        writer = Caldecott::Client::HttpTunnel::Writer.new(@log, @uri, @conn, @auth_token)
        EM.next_tick do
          writer.send_data data
          EM.next_tick do
            writer.send_data more_data
            EM.stop
          end
        end

        stub_request(:put, "#{@uri}/1")
        stub_request(:put, "#{@uri}/2")

        @validate = lambda do
          a_request(:put, "#{@uri}/1").with(:body => data).should have_been_made.once
          a_request(:put, "#{@uri}/2").with(:body => more_data).should have_been_made.once
        end
      end
    end

    it 'should not send data when closing' do
      with_em_timeout do
        data = 'some data that should not get sent'
        writer = Caldecott::Client::HttpTunnel::Writer.new(@log, @uri, @conn, @auth_token)
        EM.next_tick do
          writer.close
          writer.send_data data
          EM.next_tick { EM.stop }
        end
      end
    end

    it 'should not consume retries when already writing' do
      with_em_timeout do
        writer = Caldecott::Client::HttpTunnel::Writer.new(@log, @uri, @conn, @auth_token)

        spam = Caldecott::Client::HttpTunnel::MAX_RETRIES * 10

        got = ""
        finished = {}
        spam.times do |i|
          stub_request(:put, "#{@uri}/#{i + 1}").with do |request|
            # for some reason this callback gets executed twice,
            # even though only one request is sent
            unless finished[i]
              finished[i] = true
              got << request.body
            end

            true
          end
        end

        expected = ""
        spam.times do |i|
          EM.next_tick do
            expected << "data #{i}\n"
            writer.send_data "data #{i}\n"
          end
        end

        @validate = lambda do
          got.should == expected
        end
      end
    end
  end
end

# Copyright (c) 2009-2011 VMware, Inc.

require 'eventmachine'

module Caldecott
  # wrapper to avoid callback and state passing spaghetti
  class TcpConnection < EventMachine::Connection
    @initialzied = false

    # callbacks
    def onopen(&blk)
      @initialized ? blk.call : @onopen = blk
    end

    def onreceive(&blk)
      @onreceive = blk
    end

    def onclose(&blk)
      @onclose = blk
    end

    # handle EventMachine::Connection methods
    def post_init
      @initialized = true
      @onopen.call if @onopen
    end

    def receive_data(data)
      @onreceive.call(data) if @onreceive
    end

    def unbind
      @onclose.call if @onclose
    end

  end
end

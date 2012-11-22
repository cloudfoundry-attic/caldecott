# Copyright (c) 2009-2011 VMware, Inc.

require 'logger'

module Caldecott
  class SessionLogger < Logger
    attr_reader :component, :session
    @@session = 0

    def initialize(component, *args)
      super(*args)
      @component = component
      @session = @@session += 1
    end

    def format_message(severity, timestamp, progname, msg)
      "#{@component} [#{@session}] #{msg}\n"
    end

    def self.severity_from_string(str)
      case str.upcase
      when 'DEBUG'
        Logger::DEBUG
      when 'INFO'
        Logger::INFO
      when 'WARN'
        Logger::WARN
      when 'ERROR'
        Logger::ERROR
      when 'FATAL'
        Logger::FATAL
      when 'UNKNOWN'
        Logger::UNKNOWN
      else
        Logger::ERROR
      end
    end
  end
end

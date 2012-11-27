# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')
require 'caldecott/session_logger.rb'

describe 'session logger' do
  describe '#initialize' do
    it 'should generate unique session identifiers' do
      component = "blabla"
      logger1 = Caldecott::SessionLogger.new(component, StringIO.new)
      logger2 = Caldecott::SessionLogger.new(component, StringIO.new)

      logger1.component.should == component
      logger2.component.should == component

      logger1.session.should_not == logger2.session
    end
  end

  describe '#format_message' do
    it 'should include the component and session id' do
      component = "blabla"
      logger = Caldecott::SessionLogger.new(component, StringIO.new)

      message = "ipsum lorem"
      result = logger.format_message(Logger::DEBUG, Time.now, "test", message)
      result.should match /#{component}/
      result.should match /#{message}/
      result.should match /#{logger.session.to_s}/
    end
  end

  describe '#severity from string' do
    def validate_parsing(str, level)
      Caldecott::SessionLogger.severity_from_string(str.upcase).should == level
      Caldecott::SessionLogger.severity_from_string(str.downcase).should == level
    end

    it 'should parse DEBUG' do
      validate_parsing 'debug', Logger::DEBUG
    end

    it 'should parse INFO' do
      validate_parsing 'info', Logger::INFO
    end

    it 'should parse WARN' do
      validate_parsing 'warn', Logger::WARN
    end

    it 'should parse ERROR' do
      validate_parsing 'error', Logger::ERROR
    end

    it 'should parse FATAL' do
      validate_parsing 'fatal', Logger::FATAL
    end

    it 'should parse UNKNOWN' do
      validate_parsing 'unknown', Logger::UNKNOWN
    end

    it 'should parase bad in put as ERROR' do
      validate_parsing 'blabla', Logger::ERROR
    end
  end
end

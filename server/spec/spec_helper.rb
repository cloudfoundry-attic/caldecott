# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift File.join(File.dirname(__FILE__), '..')
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

home = File.join(File.dirname(__FILE__), '/..')
ENV['BUNDLE_GEMFILE'] = "#{home}/Gemfile"

require 'bundler'
require 'bundler/setup'
require 'rubygems'
require 'rspec'

module Caldecott
  module Test
    def with_em_timeout(timeout = 2)
      EM.run do
        EM.add_timer(timeout) do
          @validate.call if @validate
          EM.stop
        end
        yield
      end
    end
  end
end

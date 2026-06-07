# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'

  add_group 'Discovery', 'lib/robot_lab/discovery'

  enable_coverage :branch
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "robot_lab/discovery"

require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

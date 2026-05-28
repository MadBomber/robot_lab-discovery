# frozen_string_literal: true

require_relative "discovery/version"
require_relative "discovery/constants"
require_relative "discovery/txt_record"
require_relative "discovery/result"
require_relative "discovery/advertiser"
require_relative "discovery/browser"

module RobotLab
  module Discovery
    class Error < StandardError; end

    def self.browse(timeout: 3)      = Browser.browse(timeout:)
    def self.find(name, timeout: 5)  = Browser.find(name, timeout:)
  end
end

if defined?(RobotLab) && RobotLab.respond_to?(:register_extension)
  RobotLab.register_extension(:discovery, RobotLab::Discovery)
end

# frozen_string_literal: true

require "robot_lab"

require_relative "discovery/version"
require_relative "discovery/constants"
require_relative "discovery/txt_record"
require_relative "discovery/result"
require_relative "discovery/advertiser"
require_relative "discovery/browser"

module RobotLab
  module Discovery
    class Error < StandardError; end

    def self.browse(timeout: 3)                      = Browser.browse(timeout:)
    def self.find(name, timeout: 5)                  = Browser.find(name, timeout:)
    def self.find_by_capability(cap, timeout: 3)     = Browser.find_by_capability(cap, timeout:)
    def self.list_capabilities(timeout: 3)           = Browser.list_capabilities(timeout:)

    # Converts a free-form capability string into a valid DNS label:
    # downcased, non-alphanumeric runs replaced with hyphens, no leading/trailing hyphens.
    # "Web Search" → "web-search",  "NLP/Analysis" → "nlp-analysis"
    def self.dns_label(capability)
      capability.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    end

    # Coerces +capabilities+ to an array of strings and rejects any that cannot
    # be advertised: a comma would split the capability in two when the TXT
    # record is decoded, and a capability with no ASCII letter or digit
    # normalises to an empty DNS-SD subtype label.
    def self.validate_capabilities!(capabilities)
      Array(capabilities).map(&:to_s).each do |cap|
        raise ArgumentError, "capability #{cap.inspect} must not contain a comma" if cap.include?(",")
        next unless dns_label(cap).empty?

        raise ArgumentError, "capability #{cap.inspect} must contain at least one ASCII letter or digit"
      end
    end
  end
end

RobotLab.register_extension(:discovery, RobotLab::Discovery)

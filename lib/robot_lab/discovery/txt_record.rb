# frozen_string_literal: true

module RobotLab
  module Discovery
    module TxtRecord
      def self.encode(path:)
        ["path=#{path}", "rl_version=#{VERSION}"]
      end

      def self.decode(strings)
        strings.each_with_object({}) do |entry, hash|
          k, v = entry.split("=", 2)
          hash[k.to_sym] = v if k && v
        end
      end
    end
  end
end

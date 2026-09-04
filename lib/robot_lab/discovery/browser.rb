# frozen_string_literal: true

require "resolv"
require "zeroconf"

module RobotLab
  module Discovery
    module Browser
      def self.browse(timeout: 3)
        ZeroConf.browse(SERVICE_TYPE, timeout:)
                .filter_map { |r| parse_response(r) }
                .uniq(&:name)
      end

      def self.find(name, timeout: 5)
        deadline = Time.now + timeout
        loop do
          remaining = deadline - Time.now
          return nil if remaining <= 0
          result = browse(timeout: [remaining, 1].min).find { |r| r.name == name }
          return result if result
        end
      end

      def self.find_by_capability(capability, timeout: 3)
        label   = RobotLab::Discovery.dns_label(capability)
        subtype = "_#{label}._sub.#{SERVICE_TYPE}"
        ZeroConf.browse(subtype, timeout:)
                .filter_map { |r| parse_response(r) }
                .uniq(&:name)
      end

      def self.list_capabilities(timeout: 3)
        browse(timeout:)
          .flat_map(&:capabilities)
          .uniq
          .sort
      end

      # :reek:TooManyStatements -- one scan over the DNS answers accumulating SRV/TXT fields; splitting would scatter the parse state.
      def self.parse_response(response)
        instance_name = nil
        hostname      = nil
        port          = nil
        txt           = {}

        (response.answer + response.additional).each do |rname, _ttl, data|
          case data
          when Resolv::DNS::Resource::IN::SRV
            port          = data.port
            hostname      = data.target.to_s.delete_suffix(".")
            instance_name = rname.to_s.split(".").first
          when Resolv::DNS::Resource::IN::TXT
            txt = TxtRecord.decode(data.strings)
          end
        end

        return nil unless instance_name && hostname && port && txt[:path]
        Result.new(
          name:         instance_name,
          hostname:,
          port:,
          path:         txt[:path],
          capabilities: txt.fetch(:capabilities, [])
        )
      end
      private_class_method :parse_response
    end
  end
end

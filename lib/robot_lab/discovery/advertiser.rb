# frozen_string_literal: true

require "socket"
require "zeroconf"

module RobotLab
  module Discovery
    class Advertiser
      attr_reader :name, :port, :path, :hostname, :capabilities

      def initialize(name:, port:, path:, hostname: Socket.gethostname, capabilities: [])
        @name         = name
        @port         = port
        @path         = path
        @hostname     = hostname
        @capabilities = Array(capabilities).map(&:to_s)
        @service      = nil
        @thread       = nil
      end

      def start
        @service = ZeroConf::Service.new(
          SERVICE_TYPE,
          @port,
          @hostname,
          instance_name: @name,
          text:     TxtRecord.encode(path: @path, capabilities: @capabilities),
          subtypes: @capabilities.map { |c| "_#{RobotLab::Discovery.dns_label(c)}" }
        )
        @thread = Thread.new { @service.start }
        self
      end

      def stop
        @service&.stop
        @thread&.join
        @service = nil
        @thread  = nil
        self
      end

      def started? = @thread&.alive? || false
    end
  end
end

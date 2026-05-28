# frozen_string_literal: true

require "socket"
require "zeroconf"

module RobotLab
  module Discovery
    class Advertiser
      attr_reader :name, :port, :path, :hostname

      def initialize(name:, port:, path:, hostname: Socket.gethostname)
        @name     = name
        @port     = port
        @path     = path
        @hostname = hostname
        @service  = nil
        @thread   = nil
      end

      def start
        @service = ZeroConf::Service.new(
          SERVICE_TYPE,
          @port,
          @hostname,
          instance_name: @name,
          text: TxtRecord.encode(path: @path)
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

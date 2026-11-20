# frozen_string_literal: true

require "socket"
require "zeroconf"

module RobotLab
  module Discovery
    class Advertiser
      # Seconds #start waits for the service thread to announce (or fail).
      START_TIMEOUT = 5
      # Seconds #stop waits for the service thread to exit before killing it.
      STOP_TIMEOUT  = 5

      attr_reader :name, :port, :path, :hostname, :capabilities, :error

      def initialize(name:, port:, path:, hostname: Socket.gethostname, capabilities: [])
        @name         = name
        @port         = port
        @path         = path
        @hostname     = hostname
        @capabilities = RobotLab::Discovery.validate_capabilities!(capabilities)
        @service      = nil
        @thread       = nil
        @error        = nil
      end

      # Blocks until the service thread has sent its announcement, has failed,
      # or +timeout+ seconds have passed. An error raised while the service
      # was starting is re-raised here instead of dying with the thread.
      def start(timeout: START_TIMEOUT)
        ready    = Queue.new
        @error   = nil
        @service = build_service(-> { ready << :started })
        @thread  = Thread.new { run_service(ready) }
        await_start(ready, timeout)
        self
      end

      # Never blocks for more than roughly 2 × +timeout+ seconds: a service
      # thread that does not exit on request is killed.
      def stop(timeout: STOP_TIMEOUT)
        @service&.stop
        reap_thread(timeout)
        @service = nil
        @thread  = nil
        self
      end

      def started? = @thread&.alive? || false

      private

      def build_service(started_callback)
        ZeroConf::Service.new(
          SERVICE_TYPE,
          @port,
          @hostname,
          instance_name: @name,
          text:     TxtRecord.encode(path: @path, capabilities: @capabilities),
          subtypes: @capabilities.map { |c| "_#{RobotLab::Discovery.dns_label(c)}" },
          started_callback:
        )
      end

      # Thread body. Records a failure in @error rather than letting the
      # thread die silently, and always signals +ready+ so #start never waits
      # on a thread that has already finished.
      def run_service(ready)
        @service.start
      rescue StandardError => e
        @error = e
      ensure
        ready << :finished
      end

      def await_start(ready, timeout)
        ready.pop(timeout:)
        failure = @error
        return unless failure

        stop
        @error = failure
        raise failure
      end

      # ZeroConf::Service#stop is a no-op until the service has marked itself
      # started, so a thread that is still starting up would never be told to
      # exit. Bound the join and kill the thread if it is still alive; the
      # service's own ensure block still sends the goodbye and closes sockets.
      def reap_thread(timeout)
        return unless @thread
        return if @thread.join(timeout)

        @thread.kill
        @thread.join(timeout)
      end
    end
  end
end

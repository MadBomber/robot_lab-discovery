# frozen_string_literal: true

require "test_helper"
require "timeout"

class TestAdvertiser < Minitest::Test
  def setup
    @advertiser = RobotLab::Discovery::Advertiser.new(
      name:         "headline",
      port:         9292,
      path:         "/headline",
      hostname:     "test-host",
      capabilities: %w[writing research]
    )
  end

  def test_stores_name
    assert_equal "headline", @advertiser.name
  end

  def test_stores_port
    assert_equal 9292, @advertiser.port
  end

  def test_stores_path
    assert_equal "/headline", @advertiser.path
  end

  def test_stores_hostname
    assert_equal "test-host", @advertiser.hostname
  end

  def test_stores_capabilities_as_strings
    assert_equal %w[writing research], @advertiser.capabilities
  end

  def test_empty_capabilities_by_default
    a = RobotLab::Discovery::Advertiser.new(name: "x", port: 9292, path: "/x")
    assert_equal [], a.capabilities
  end

  def test_capabilities_coerced_to_strings
    a = RobotLab::Discovery::Advertiser.new(
      name: "x", port: 9292, path: "/x", capabilities: %i[research writing]
    )
    assert_equal %w[research writing], a.capabilities
  end

  def test_not_started_initially
    refute @advertiser.started?
  end

  def test_uses_system_hostname_by_default
    a = RobotLab::Discovery::Advertiser.new(name: "x", port: 9292, path: "/x")
    assert_equal Socket.gethostname, a.hostname
  end

  def test_start_returns_self
    fake_service = Minitest::Mock.new
    fake_service.expect(:start, nil)
    fake_service.expect(:stop, nil)

    ZeroConf::Service.stub(:new, fake_service) do
      result = @advertiser.start
      assert_same @advertiser, result
      @advertiser.stop
    end

    fake_service.verify
  end

  def test_stop_returns_self
    fake_service = Minitest::Mock.new
    fake_service.expect(:start, nil)
    fake_service.expect(:stop, nil)

    ZeroConf::Service.stub(:new, fake_service) do
      @advertiser.start
      assert_same @advertiser, @advertiser.stop
    end

    fake_service.verify
  end

  def test_stop_when_not_started_is_safe
    assert_same @advertiser, @advertiser.stop
  end

  # ---------------------------------------------------------------------------
  # Lifecycle against a fake ZeroConf::Service (no mDNS traffic)
  # ---------------------------------------------------------------------------

  # Stands in for ZeroConf::Service. #start blocks like the real service loop
  # until #stop (or a pushed exception) releases it.
  class FakeService
    attr_reader :gate, :stop_calls

    def initialize(started_callback:, start_error: nil, announce: true, honor_stop: true)
      @started_callback = started_callback
      @start_error      = start_error
      @announce         = announce
      @honor_stop       = honor_stop
      @gate             = Queue.new
      @stop_calls       = 0
    end

    def start
      raise @start_error if @start_error

      @started_callback&.call if @announce
      signal = @gate.pop
      raise signal if signal.is_a?(Exception)
    end

    def stop
      @stop_calls += 1
      @gate << :stop if @honor_stop
    end
  end

  def with_fake_service(**fake_opts)
    captured = {}
    factory  = lambda do |*args, **opts|
      captured[:args] = args
      captured[:opts] = opts
      captured[:service] = FakeService.new(started_callback: opts[:started_callback], **fake_opts)
    end
    ZeroConf::Service.stub(:new, factory) { yield captured }
  end

  def wait_until(limit = 2)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + limit
    sleep 0.01 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  end

  def test_start_builds_service_from_attributes
    with_fake_service do |captured|
      @advertiser.start
      @advertiser.stop

      assert_equal [RobotLab::Discovery::SERVICE_TYPE, 9292, "test-host"], captured[:args]
      assert_equal "headline", captured[:opts][:instance_name]
      assert_equal %w[_writing _research], captured[:opts][:subtypes]
      assert_includes captured[:opts][:text], "c=writing,research"
    end
  end

  def test_started_true_while_service_runs_and_false_after_stop
    with_fake_service do |captured|
      @advertiser.start
      assert @advertiser.started?
      assert_nil @advertiser.error

      @advertiser.stop
      refute @advertiser.started?
      assert_equal 1, captured[:service].stop_calls
    end
  end

  # Regression: ZeroConf::Service#stop is a no-op until the service has marked
  # itself started, so an unbounded join in #stop used to hang forever.
  def test_stop_never_hangs_when_service_ignores_stop
    with_fake_service(announce: false, honor_stop: false) do
      @advertiser.start(timeout: 0.05)
      assert @advertiser.started?

      Timeout.timeout(5) { assert_same @advertiser, @advertiser.stop(timeout: 0.05) }
      refute @advertiser.started?
    end
  end

  def test_start_gives_up_waiting_after_timeout
    with_fake_service(announce: false) do
      Timeout.timeout(5) { assert_same @advertiser, @advertiser.start(timeout: 0.05) }
      @advertiser.stop
    end
  end

  # Regression: an error in the service thread used to vanish until #stop.
  def test_start_raises_error_from_service_thread
    boom = Errno::EADDRINUSE.new("5353")
    with_fake_service(start_error: boom) do
      raised = assert_raises(Errno::EADDRINUSE) { @advertiser.start }

      assert_same boom, raised
      assert_same boom, @advertiser.error
      refute @advertiser.started?
    end
  end

  def test_error_after_start_is_recorded_and_started_becomes_false
    boom = RuntimeError.new("socket died")
    with_fake_service do |captured|
      @advertiser.start
      captured[:service].gate << boom
      wait_until { !@advertiser.started? }

      refute @advertiser.started?
      assert_same boom, @advertiser.error
      assert_same @advertiser, @advertiser.stop
    end
  end

  def test_restart_clears_previous_error
    boom = RuntimeError.new("first run failed")
    with_fake_service(start_error: boom) { assert_raises(RuntimeError) { @advertiser.start } }

    with_fake_service do
      @advertiser.start
      assert_nil @advertiser.error
      @advertiser.stop
    end
  end

  def test_start_raises_txt_error_without_spawning_thread
    a = RobotLab::Discovery::Advertiser.new(name: "x", port: 9292, path: "/#{"a" * 300}")
    assert_raises(RobotLab::Discovery::Error) { a.start }
    refute a.started?
  end

  # ---------------------------------------------------------------------------
  # Capability validation
  # ---------------------------------------------------------------------------

  def test_rejects_capability_containing_comma
    err = assert_raises(ArgumentError) do
      RobotLab::Discovery::Advertiser.new(name: "x", port: 9292, path: "/x", capabilities: ["a,b"])
    end
    assert_match(/comma/, err.message)
  end

  def test_rejects_capability_that_normalises_to_empty_label
    err = assert_raises(ArgumentError) do
      RobotLab::Discovery::Advertiser.new(name: "x", port: 9292, path: "/x", capabilities: ["research", "!!!"])
    end
    assert_match(/letter or digit/, err.message)
  end
end

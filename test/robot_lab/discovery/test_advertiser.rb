# frozen_string_literal: true

require "test_helper"

class TestAdvertiser < Minitest::Test
  def setup
    @advertiser = RobotLab::Discovery::Advertiser.new(
      name:         "headline",
      port:         9292,
      path:         "/headline",
      hostname:     "test-host",
      capabilities: ["writing", "research"]
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
    assert_equal ["writing", "research"], @advertiser.capabilities
  end

  def test_empty_capabilities_by_default
    a = RobotLab::Discovery::Advertiser.new(name: "x", port: 9292, path: "/x")
    assert_equal [], a.capabilities
  end

  def test_capabilities_coerced_to_strings
    a = RobotLab::Discovery::Advertiser.new(
      name: "x", port: 9292, path: "/x", capabilities: [:research, :writing]
    )
    assert_equal ["research", "writing"], a.capabilities
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
end

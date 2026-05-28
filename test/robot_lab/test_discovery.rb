# frozen_string_literal: true

require "test_helper"

class TestDiscovery < Minitest::Test
  def test_version_exists
    refute_nil RobotLab::Discovery::VERSION
  end

  def test_service_type_constant
    assert_equal "_robot-lab._tcp.local.", RobotLab::Discovery::SERVICE_TYPE
  end

  def test_error_is_standard_error_subclass
    assert RobotLab::Discovery::Error.ancestors.include?(StandardError)
  end

  def test_browse_delegates_to_browser
    responses = []
    RobotLab::Discovery::Browser.stub(:browse, responses) do
      assert_equal responses, RobotLab::Discovery.browse
    end
  end

  def test_find_delegates_to_browser
    result = RobotLab::Discovery::Result.new(name: "test", hostname: "host.local", port: 9292, path: "/test")
    RobotLab::Discovery::Browser.stub(:find, result) do
      assert_equal result, RobotLab::Discovery.find("test")
    end
  end
end

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
    result = RobotLab::Discovery::Result.new(
      name: "test", hostname: "host.local", port: 9292, path: "/test", capabilities: []
    )
    RobotLab::Discovery::Browser.stub(:find, result) do
      assert_equal result, RobotLab::Discovery.find("test")
    end
  end

  def test_find_by_capability_delegates_to_browser
    results = []
    RobotLab::Discovery::Browser.stub(:find_by_capability, results) do
      assert_equal results, RobotLab::Discovery.find_by_capability("research")
    end
  end

  def test_list_capabilities_delegates_to_browser
    caps = %w[analysis research]
    RobotLab::Discovery::Browser.stub(:list_capabilities, caps) do
      assert_equal caps, RobotLab::Discovery.list_capabilities
    end
  end

  def test_dns_label_downcases
    assert_equal "research", RobotLab::Discovery.dns_label("Research")
  end

  def test_dns_label_replaces_spaces_with_hyphens
    assert_equal "web-search", RobotLab::Discovery.dns_label("Web Search")
  end

  def test_dns_label_replaces_special_chars
    assert_equal "nlp-analysis", RobotLab::Discovery.dns_label("NLP/Analysis")
  end

  def test_dns_label_collapses_multiple_separators
    assert_equal "a-b", RobotLab::Discovery.dns_label("a  /  b")
  end

  def test_dns_label_strips_leading_trailing_hyphens
    assert_equal "foo", RobotLab::Discovery.dns_label("-foo-")
  end
end

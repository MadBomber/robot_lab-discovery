# frozen_string_literal: true

require "test_helper"

class TestResult < Minitest::Test
  def setup
    @result = RobotLab::Discovery::Result.new(
      name:         "headline",
      hostname:     "my-server.local",
      port:         9292,
      path:         "/headline",
      capabilities: %w[writing research]
    )
  end

  def test_url_combines_parts
    assert_equal "http://my-server.local:9292/headline", @result.url
  end

  def test_name_accessible
    assert_equal "headline", @result.name
  end

  def test_hostname_accessible
    assert_equal "my-server.local", @result.hostname
  end

  def test_port_accessible
    assert_equal 9292, @result.port
  end

  def test_path_accessible
    assert_equal "/headline", @result.path
  end

  def test_capabilities_accessible
    assert_equal %w[writing research], @result.capabilities
  end

  def test_empty_capabilities
    r = RobotLab::Discovery::Result.new(
      name: "x", hostname: "h.local", port: 80, path: "/x", capabilities: []
    )
    assert_equal [], r.capabilities
  end

  def test_equality_by_value
    other = RobotLab::Discovery::Result.new(
      name: "headline", hostname: "my-server.local", port: 9292,
      path: "/headline", capabilities: %w[writing research]
    )
    assert_equal @result, other
  end

  def test_immutable
    assert_raises(NoMethodError) { @result.name = "changed" }
  end

  def test_url_with_nested_path
    r = RobotLab::Discovery::Result.new(
      name: "x", hostname: "h.local", port: 80, path: "/a/b/c", capabilities: []
    )
    assert_equal "http://h.local:80/a/b/c", r.url
  end
end

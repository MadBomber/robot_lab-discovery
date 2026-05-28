# frozen_string_literal: true

require "test_helper"

class TestTxtRecord < Minitest::Test
  def test_encode_includes_path
    result = RobotLab::Discovery::TxtRecord.encode(path: "/headline")
    assert_includes result, "path=/headline"
  end

  def test_encode_includes_version
    result = RobotLab::Discovery::TxtRecord.encode(path: "/headline")
    assert(result.any? { |s| s.start_with?("rl_version=") })
  end

  def test_encode_returns_array
    assert_instance_of Array, RobotLab::Discovery::TxtRecord.encode(path: "/tags")
  end

  def test_decode_parses_path
    strings = ["path=/headline", "rl_version=0.1.0"]
    result  = RobotLab::Discovery::TxtRecord.decode(strings)
    assert_equal "/headline", result[:path]
  end

  def test_decode_parses_version
    strings = ["path=/headline", "rl_version=0.1.0"]
    result  = RobotLab::Discovery::TxtRecord.decode(strings)
    assert_equal "0.1.0", result[:rl_version]
  end

  def test_decode_ignores_entries_without_value
    strings = ["malformed", "path=/ok"]
    result  = RobotLab::Discovery::TxtRecord.decode(strings)
    assert_equal "/ok", result[:path]
    refute result.key?(:malformed)
  end

  def test_decode_handles_values_containing_equals
    strings = ["path=/foo=bar"]
    result  = RobotLab::Discovery::TxtRecord.decode(strings)
    assert_equal "/foo=bar", result[:path]
  end

  def test_roundtrip
    original = RobotLab::Discovery::TxtRecord.encode(path: "/pipeline")
    decoded  = RobotLab::Discovery::TxtRecord.decode(original)
    assert_equal "/pipeline", decoded[:path]
  end
end

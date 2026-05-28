# frozen_string_literal: true

require "test_helper"

class TestTxtRecord < Minitest::Test
  TXT = RobotLab::Discovery::TxtRecord

  # ---------------------------------------------------------------------------
  # Encode — wire format uses short keys (p=, v=, c=)
  # ---------------------------------------------------------------------------

  def test_encode_includes_path_with_short_key
    assert_includes TXT.encode(path: "/headline"), "p=/headline"
  end

  def test_encode_includes_version_with_short_key
    assert TXT.encode(path: "/headline").any? { |s| s.start_with?("v=") }
  end

  def test_encode_returns_array
    assert_instance_of Array, TXT.encode(path: "/tags")
  end

  def test_encode_omits_capabilities_when_empty
    refute TXT.encode(path: "/x").any? { |s| s.start_with?("c=") }
  end

  def test_encode_includes_capabilities_with_short_key
    assert_includes TXT.encode(path: "/x", capabilities: ["research", "writing"]),
                    "c=research,writing"
  end

  def test_encode_accepts_single_capability
    assert_includes TXT.encode(path: "/x", capabilities: ["research"]), "c=research"
  end

  def test_encode_does_not_use_long_keys
    record = TXT.encode(path: "/x", capabilities: ["research"])
    refute record.any? { |s| s.start_with?("path=", "rl_version=", "capabilities=") }
  end

  # ---------------------------------------------------------------------------
  # Decode — maps short keys back to semantic symbols
  # ---------------------------------------------------------------------------

  def test_decode_parses_path
    assert_equal "/headline", TXT.decode(["p=/headline", "v=0.1.0"])[:path]
  end

  def test_decode_parses_version
    assert_equal "0.1.0", TXT.decode(["p=/headline", "v=0.1.0"])[:rl_version]
  end

  def test_decode_parses_capabilities_as_array
    assert_equal ["research", "writing"],
                 TXT.decode(["p=/x", "c=research,writing"])[:capabilities]
  end

  def test_decode_single_capability_is_array
    assert_equal ["research"], TXT.decode(["p=/x", "c=research"])[:capabilities]
  end

  def test_decode_missing_capabilities_returns_no_key
    refute TXT.decode(["p=/x", "v=0.1.0"]).key?(:capabilities)
  end

  def test_decode_ignores_unknown_keys
    result = TXT.decode(["p=/ok", "z=unknown"])
    assert_equal "/ok", result[:path]
    refute result.key?(:z)
  end

  def test_decode_handles_values_containing_equals
    assert_equal "/foo=bar", TXT.decode(["p=/foo=bar"])[:path]
  end

  # ---------------------------------------------------------------------------
  # Roundtrip
  # ---------------------------------------------------------------------------

  def test_roundtrip_with_capabilities
    original = TXT.encode(path: "/pipeline", capabilities: ["analysis", "coding"])
    decoded  = TXT.decode(original)
    assert_equal "/pipeline",            decoded[:path]
    assert_equal ["analysis", "coding"], decoded[:capabilities]
  end

  # ---------------------------------------------------------------------------
  # Validation — per-string limit (RFC 1035: 255 bytes max per string)
  # ---------------------------------------------------------------------------

  def test_validate_raises_when_path_string_exceeds_255_bytes
    # "p=" is 2 bytes, so path content must exceed 253 bytes to trigger.
    long_path = "/#{("a" * 254)}"
    err = assert_raises(RobotLab::Discovery::Error) { TXT.encode(path: long_path) }
    assert_match(/exceeds #{TXT::MAX_STRING_BYTES} bytes/, err.message)
  end

  def test_validate_passes_for_path_string_at_exactly_255_bytes
    # "p=" is 2 bytes; path content of 253 bytes → string is exactly 255 bytes.
    path = "/#{("a" * 252)}"
    assert_equal 255, "p=#{path}".bytesize
    assert TXT.encode(path: path).any? { |s| s.start_with?("p=") }
  end

  def test_validate_raises_when_capabilities_string_exceeds_255_bytes
    # "c=" is 2 bytes; capability content must exceed 253 bytes.
    long_cap = "a" * 254
    err = assert_raises(RobotLab::Discovery::Error) do
      TXT.encode(path: "/x", capabilities: [long_cap])
    end
    assert_match(/exceeds #{TXT::MAX_STRING_BYTES} bytes/, err.message)
  end

  def test_max_capabilities_content_constant
    assert_equal 253, TXT::MAX_CAPABILITIES_CONTENT
  end

  def test_validate_error_message_includes_byte_count
    long_path = "/#{("b" * 254)}"
    err = assert_raises(RobotLab::Discovery::Error) { TXT.encode(path: long_path) }
    assert_match(/\d+ bytes/, err.message)
  end

  # ---------------------------------------------------------------------------
  # Validation — total wire size limit (~1300 bytes to avoid UDP fragmentation)
  # ---------------------------------------------------------------------------

  def test_validate_raises_when_total_wire_size_exceeds_limit
    # validate! is called directly here because encode produces at most 3 strings
    # (p=, v=, c=), each capped at 255 bytes, so the total limit of 1300 bytes
    # cannot be reached through encode alone. The total check guards callers who
    # build strings outside of encode.
    #
    # 6 strings × 220 bytes each → wire size = 6 × (1 + 220) = 1326 > 1300.
    strings = Array.new(6) { "a" * 220 }
    err = assert_raises(RobotLab::Discovery::Error) { TXT.validate!(strings) }
    assert_match(/wire size exceeds #{TXT::MAX_TOTAL_BYTES} bytes/, err.message)
  end

  def test_validate_passes_for_record_just_under_total_limit
    # 5 strings × 220 bytes each → wire size = 5 × (1 + 220) = 1105 < 1300.
    strings = Array.new(5) { "a" * 220 }
    assert_same strings, TXT.validate!(strings)
  end

  def test_validate_total_error_message_includes_byte_count
    strings = Array.new(6) { "a" * 220 }
    err = assert_raises(RobotLab::Discovery::Error) { TXT.validate!(strings) }
    assert_match(/\(\d+ bytes\)/, err.message)
  end

  def test_validate_bang_returns_strings_when_valid
    strings = ["p=/x", "v=0.1.0"]
    assert_same strings, TXT.validate!(strings)
  end
end

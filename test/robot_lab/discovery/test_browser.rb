# frozen_string_literal: true

require "test_helper"

class TestBrowser < Minitest::Test
  SRV = Resolv::DNS::Resource::IN::SRV
  TXT = Resolv::DNS::Resource::IN::TXT

  def srv_data(port:, target:)
    SRV.new(0, 0, port, Resolv::DNS::Name.create(target))
  end

  def txt_data(strings)
    TXT.new(*strings)
  end

  def fake_response(instance_name:, hostname:, port:, path:, capabilities: [])
    strings = ["p=#{path}", "v=0.1.0"]
    strings << "c=#{capabilities.join(",")}" unless capabilities.empty?

    srv   = srv_data(port:, target: "#{hostname}.")
    txt   = txt_data(strings)
    rname = Resolv::DNS::Name.create("#{instance_name}._robot-lab._tcp.local.")

    msg = Minitest::Mock.new
    msg.expect(:answer,     [])
    msg.expect(:additional, [[rname, 60, srv], [rname, 60, txt]])
    msg
  end

  def test_parse_returns_nil_without_srv
    msg = Minitest::Mock.new
    msg.expect(:answer,     [])
    msg.expect(:additional, [])
    assert_nil RobotLab::Discovery::Browser.send(:parse_response, msg)
  end

  def test_parse_returns_nil_without_txt_path
    rname = Resolv::DNS::Name.create("headline._robot-lab._tcp.local.")
    srv   = srv_data(port: 9292, target: "myhost.local.")
    txt   = txt_data(["v=0.1.0"])

    msg = Minitest::Mock.new
    msg.expect(:answer,     [])
    msg.expect(:additional, [[rname, 60, srv], [rname, 60, txt]])

    assert_nil RobotLab::Discovery::Browser.send(:parse_response, msg)
  end

  def test_parse_builds_result
    msg    = fake_response(instance_name: "headline", hostname: "myhost.local",
                           port: 9292, path: "/headline", capabilities: ["writing"])
    result = RobotLab::Discovery::Browser.send(:parse_response, msg)

    assert_equal "headline",    result.name
    assert_equal "myhost.local", result.hostname
    assert_equal 9292,          result.port
    assert_equal "/headline",   result.path
    assert_equal ["writing"],   result.capabilities
  end

  def test_parse_capabilities_empty_when_absent
    msg    = fake_response(instance_name: "tags", hostname: "h.local", port: 9292, path: "/tags")
    result = RobotLab::Discovery::Browser.send(:parse_response, msg)
    assert_equal [], result.capabilities
  end

  def test_parse_strips_trailing_dot_from_hostname
    msg    = fake_response(instance_name: "tags", hostname: "host.local", port: 9292, path: "/tags")
    result = RobotLab::Discovery::Browser.send(:parse_response, msg)
    refute result.hostname.end_with?(".")
  end

  def test_browse_deduplicates_by_name
    msg1 = fake_response(instance_name: "headline", hostname: "h.local", port: 9292, path: "/headline")
    msg2 = fake_response(instance_name: "headline", hostname: "h.local", port: 9292, path: "/headline")

    ZeroConf.stub(:browse, [msg1, msg2]) do
      assert_equal 1, RobotLab::Discovery::Browser.browse.size
    end
  end

  def test_browse_returns_multiple_robots
    msg1 = fake_response(instance_name: "headline", hostname: "h.local", port: 9292,
                         path: "/headline", capabilities: ["writing"])
    msg2 = fake_response(instance_name: "tags",     hostname: "h.local", port: 9292,
                         path: "/tags",     capabilities: ["analysis"])

    ZeroConf.stub(:browse, [msg1, msg2]) do
      results = RobotLab::Discovery::Browser.browse
      assert_equal 2, results.size
      assert_equal %w[headline tags], results.map(&:name)
    end
  end

  def test_find_returns_matching_result
    msg = fake_response(instance_name: "headline", hostname: "h.local", port: 9292, path: "/headline")

    ZeroConf.stub(:browse, [msg]) do
      result = RobotLab::Discovery::Browser.find("headline", timeout: 2)
      assert_equal "headline", result.name
    end
  end

  def test_find_returns_nil_when_not_found
    ZeroConf.stub(:browse, []) do
      assert_nil RobotLab::Discovery::Browser.find("missing", timeout: 0.1)
    end
  end

  def test_find_by_capability_browses_subtype
    msg = fake_response(instance_name: "headline", hostname: "h.local", port: 9292,
                        path: "/headline", capabilities: ["writing"])

    browsed_type = nil
    ZeroConf.stub(:browse, lambda { |type, **|
      browsed_type = type
      [msg]
    }) do
      RobotLab::Discovery::Browser.find_by_capability("writing")
    end

    assert_equal "_writing._sub._robot-lab._tcp.local.", browsed_type
  end

  def test_find_by_capability_sanitizes_label
    msg = fake_response(instance_name: "x", hostname: "h.local", port: 9292,
                        path: "/x", capabilities: ["web-search"])

    browsed_type = nil
    ZeroConf.stub(:browse, lambda { |type, **|
      browsed_type = type
      [msg]
    }) do
      RobotLab::Discovery::Browser.find_by_capability("Web Search")
    end

    assert_equal "_web-search._sub._robot-lab._tcp.local.", browsed_type
  end

  def test_list_capabilities_collects_and_sorts
    msg1 = fake_response(instance_name: "a", hostname: "h.local", port: 9292,
                         path: "/a", capabilities: %w[writing research])
    msg2 = fake_response(instance_name: "b", hostname: "h.local", port: 9292,
                         path: "/b", capabilities: %w[research analysis])

    ZeroConf.stub(:browse, [msg1, msg2]) do
      caps = RobotLab::Discovery::Browser.list_capabilities
      assert_equal %w[analysis research writing], caps
    end
  end

  def test_list_capabilities_empty_when_none_advertised
    msg = fake_response(instance_name: "a", hostname: "h.local", port: 9292, path: "/a")

    ZeroConf.stub(:browse, [msg]) do
      assert_equal [], RobotLab::Discovery::Browser.list_capabilities
    end
  end
end

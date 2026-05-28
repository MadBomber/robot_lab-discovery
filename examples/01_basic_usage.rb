#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/01_basic_usage.rb
#
# Demonstrates the complete lifecycle of robot service discovery on a local
# network using multicast DNS (mDNS / RFC 6762):
#
#   Register  — Advertiser announces robots under _robot-lab._tcp.local.,
#               encoding each robot's HTTP path and capability taxonomy in its
#               TXT record and as DNS-SD subtypes.
#
#   Browse    — Discovery.browse() returns every robot on the LAN, with its
#               name, hostname, port, path, capabilities, and url.
#
#   By name   — Discovery.find() targets a single robot by instance name.
#
#   By capability — Discovery.find_by_capability() browses a DNS-SD subtype
#               (e.g. _research._sub._robot-lab._tcp.local.) and returns only
#               robots that advertise that capability.
#
#   Inventory — Discovery.list_capabilities() collects every capability term
#               advertised on the LAN and returns them sorted and deduped.
#
#   Unregister — Stopping an Advertiser sends an mDNS goodbye packet (TTL=0),
#                removing the service from peers' caches immediately.
#
# Prerequisites:
#   A multicast-capable network interface (standard on any LAN).
#   The zeroconf gem is pure Ruby — no Bonjour, Avahi, or system daemon needed.
#
# Note: both advertisers and browser run in the same process here for demo
# purposes. In production each robot's server process runs its own Advertiser.

require_relative "common"

ROBOT_PORT     = 9292
BROWSE_TIMEOUT = 3  # seconds to listen for mDNS responses

# ---------------------------------------------------------------------------
# 1. Register robots on the local network
# ---------------------------------------------------------------------------
puts "=== Registering robots ==="

robots = [
  { name: "headline",      path: "/headline",      capabilities: ["writing", "research"]  },
  { name: "tags",          path: "/tags",           capabilities: ["analysis"]             },
  { name: "market-analyst",path: "/market-analyst", capabilities: ["research", "analysis"] },
]

advertisers = robots.map do |r|
  adv = RobotLab::Discovery::Advertiser.new(
    name:         r[:name],
    port:         ROBOT_PORT,
    path:         r[:path],
    hostname:     Socket.gethostname,
    capabilities: r[:capabilities]
  )
  adv.start
  puts "  [+] #{r[:name]} (#{r[:capabilities].join(", ")}) → #{adv.hostname}.local:#{ROBOT_PORT}#{r[:path]}"
  adv
end

puts

# Allow mDNS announcements to propagate across the multicast group before
# browsing. The zeroconf Service sends its announcement immediately on start,
# but peers may need a moment to process it.
sleep 1

# ---------------------------------------------------------------------------
# 2. Browse all robots on the local network
# ---------------------------------------------------------------------------
puts "=== Browsing local network (timeout: #{BROWSE_TIMEOUT}s) ==="

results = RobotLab::Discovery.browse(timeout: BROWSE_TIMEOUT)

if results.empty?
  puts "  No robots found."
else
  puts "  Found #{results.size} robot(s):\n\n"
  results.each do |r|
    caps = r.capabilities.empty? ? "(none)" : r.capabilities.join(", ")
    puts <<~RESULT
        Name         : #{r.name}
        Hostname     : #{r.hostname}
        Port         : #{r.port}
        Path         : #{r.path}
        Capabilities : #{caps}
        URL          : #{r.url}

    RESULT
  end
end

# ---------------------------------------------------------------------------
# 3. Find a specific robot by name
# ---------------------------------------------------------------------------
puts "=== Finding 'headline' by name ==="

result = RobotLab::Discovery.find("headline", timeout: BROWSE_TIMEOUT)

if result
  puts "  Found: #{result.url}"
  puts "  Capabilities: #{result.capabilities.join(", ")}"
else
  puts "  'headline' not found within #{BROWSE_TIMEOUT}s."
end

puts

# ---------------------------------------------------------------------------
# 4. Find robots by capability
# ---------------------------------------------------------------------------
puts "=== Finding all 'research' robots ==="

researchers = RobotLab::Discovery.find_by_capability("research", timeout: BROWSE_TIMEOUT)

if researchers.empty?
  puts "  No research robots found."
else
  puts "  Found #{researchers.size} research robot(s):"
  researchers.each { |r| puts "    #{r.name} — #{r.url}" }
end

puts

# ---------------------------------------------------------------------------
# 5. List all capability types available on the LAN
# ---------------------------------------------------------------------------
puts "=== Available capability types ==="

caps = RobotLab::Discovery.list_capabilities(timeout: BROWSE_TIMEOUT)

if caps.empty?
  puts "  None advertised."
else
  caps.each { |c| puts "    #{c}" }
end

puts

# ---------------------------------------------------------------------------
# 6. Unregister — send mDNS goodbye packets
# ---------------------------------------------------------------------------
puts "=== Unregistering robots ==="

advertisers.each do |adv|
  adv.stop
  puts "  [-] #{adv.name} unregistered"
end

puts
puts "Done."

#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/01_basic_usage.rb
#
# Demonstrates the complete lifecycle of robot service discovery on a local
# network using mDNS (Bonjour/Avahi):
#
#   Register  — Advertiser announces two robots under the _robot-lab._tcp.local.
#               service type, encoding each robot's HTTP path in its TXT record.
#
#   Browse    — Discovery.browse() listens for mDNS responses and returns a
#               Result for every robot it finds.
#
#   Inspect   — Each Result carries name, hostname, port, path, and a url()
#               helper that assembles the A2A endpoint ready for a client.
#
#   Unregister — Stopping an Advertiser sends an mDNS goodbye packet (TTL=0),
#                removing the service from peers' caches immediately.
#
# Prerequisites:
#   A multicast-capable network interface (standard on any LAN).
#   The zeroconf gem is pure Ruby — no Bonjour, Avahi, or system daemon needed.
#
# Note: both advertiser and browser run in the same process here for demo
# purposes. In production each robot's server process runs its own Advertiser.

require_relative "common"

ROBOT_PORT = 9292
BROWSE_TIMEOUT = 3  # seconds to listen for mDNS responses

# ---------------------------------------------------------------------------
# 1. Register robots on the local network
# ---------------------------------------------------------------------------
puts "=== Registering robots ==="

robots = [
  { name: "headline", path: "/headline" },
  { name: "tags",     path: "/tags"     },
]

advertisers = robots.map do |r|
  adv = RobotLab::Discovery::Advertiser.new(
    name:     r[:name],
    port:     ROBOT_PORT,
    path:     r[:path],
    hostname: Socket.gethostname
  )
  adv.start
  puts "  [+] #{r[:name]} → #{adv.hostname}.local:#{ROBOT_PORT}#{r[:path]}"
  adv
end

puts

# Allow mDNS announcements to propagate across the multicast group before
# browsing. The zeroconf Service sends its announcement immediately on start,
# but peers may need a moment to process it.
sleep 1

# ---------------------------------------------------------------------------
# 2. Browse the local network for registered robots
# ---------------------------------------------------------------------------
puts "=== Browsing local network (timeout: #{BROWSE_TIMEOUT}s) ==="

results = RobotLab::Discovery.browse(timeout: BROWSE_TIMEOUT)

if results.empty?
  puts "  No robots found."
else
  puts "  Found #{results.size} robot(s):"
  results.each do |r|
    puts <<~RESULT
        Name     : #{r.name}
        Hostname : #{r.hostname}
        Port     : #{r.port}
        Path     : #{r.path}
        URL      : #{r.url}

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
  puts "  Ready to connect — pass result.url to your A2A client."
else
  puts "  'headline' not found within #{BROWSE_TIMEOUT}s."
end

puts

# ---------------------------------------------------------------------------
# 4. Unregister — send mDNS goodbye packets
# ---------------------------------------------------------------------------
puts "=== Unregistering robots ==="

advertisers.each do |adv|
  adv.stop
  puts "  [-] #{adv.name} unregistered"
end

puts
puts "Done."

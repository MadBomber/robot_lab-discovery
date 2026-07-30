# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-discovery` provides zero-configuration mDNS/DNS-SD robot discovery on local networks. Robots advertise themselves with a name, port, path, and optional capabilities; browsers discover them by name or capability without any central registry.

Uses the `zeroconf` gem. Service type is `_robot-lab._tcp.local.`.

## Commands

```bash
bundle exec rake test        # Run full test suite (SpecReporter output)
ruby -Ilib:test test/<file>  # Run a single test file
```

## Architecture

All source lives under `lib/robot_lab/discovery/`.

**`Discovery`** (`discovery.rb`) — Top-level module with delegation methods:
- `browse(timeout:)` — returns all visible robots as `Array<Result>`
- `find(name, timeout:)` — polls until the named robot appears or timeout
- `find_by_capability(cap, timeout:)` — browses the capability-specific DNS subtype
- `list_capabilities(timeout:)` — returns sorted unique capability strings across all visible robots
- `dns_label(capability)` — normalises a capability string to a valid DNS label (`"Web Search"` → `"web-search"`)

**`Advertiser`** (`discovery/advertiser.rb`) — Announces a robot over mDNS. `start` spawns a background thread running the zeroconf service; `stop` tears it down. Each capability is registered as a DNS subtype (`_capability-label._sub._robot-lab._tcp.local.`) enabling capability-filtered browsing.

**`Browser`** (`discovery/browser.rb`) — Wraps `ZeroConf.browse`. Parses raw DNS responses (SRV + TXT records) into `Result` structs, deduplicating by name. `parse_response` is private — do not call directly.

**`TxtRecord`** (`discovery/txt_record.rb`) — Encodes/decodes the DNS TXT payload using short wire keys to conserve UDP packet space:
- `p` = path, `v` = rl_version, `c` = comma-joined capabilities
- `encode` validates each string ≤ 255 bytes and total wire size ≤ 1300 bytes
- `decode` returns `{ path:, rl_version:, capabilities: [] }`

**`Result`** (`discovery/result.rb`) — `Data.define(:name, :hostname, :port, :path, :capabilities)`. Has a `url` convenience method (`"http://hostname:port/path"`).

**`Constants`** (`discovery/constants.rb`) — `SERVICE_TYPE = "_robot-lab._tcp.local."`.

## Usage Example

```ruby
require 'robot_lab/discovery'

# Advertise
adv = RobotLab::Discovery::Advertiser.new(
  name: "analyst", port: 9292, path: "/a2a",
  capabilities: ["data analysis", "web search"]
)
adv.start

# Browse
robots = RobotLab::Discovery.browse(timeout: 3)
robots.each { |r| puts "#{r.name} at #{r.url}" }

# Find by capability
RobotLab::Discovery.find_by_capability("web search", timeout: 3)
```

## Key Constraints

- mDNS is LAN-only — works within a single subnet, not across routers.
- `browse` may return stale results if a robot crashes without calling `stop` — mDNS TTLs eventually expire.
- Capability strings in TXT records are comma-separated in a single field capped at 253 bytes of content. Many short capabilities are fine; very long strings will raise `Discovery::Error`.
- `find` polls by calling `browse` in a loop — it is blocking and should not be called on the main thread in production.

## Testing

- Minitest with SimpleCov (branch coverage tracked, no minimum threshold enforced yet)
- Output via `Minitest::Reporters::SpecReporter`
- Tests mock zeroconf interactions — no actual mDNS traffic is sent
- Coverage baseline: ~47% line / ~3% branch — test suite is thin relative to implementation

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-discovery` provides zero-configuration mDNS/DNS-SD robot discovery on local networks. Robots advertise themselves with a name, port, path, and optional capabilities; browsers discover them by name or capability without any central registry.

Uses the `zeroconf` gem. Service type is `_robot-lab._tcp.local.`.

## Commands

```bash
bundle exec rake test        # Run full test suite (SpecReporter output)
ruby -Ilib:test test/<file>  # Run a single test file (tests run, but SimpleCov exits 2 — one file can't meet the coverage minimums)
```

## Architecture

Source lives in `lib/robot_lab/discovery.rb` and under `lib/robot_lab/discovery/`. The gemspec depends on `robot_lab ~> 0.6` and `zeroconf ~> 1.3`; `discovery.rb` requires `robot_lab` and always calls `RobotLab.register_extension(:discovery, RobotLab::Discovery)`; nothing else in the lib touches core.

**`Discovery`** (`discovery.rb`) — Top-level module with delegation methods:
- `browse(timeout:)` — returns all visible robots as `Array<Result>`
- `find(name, timeout:)` — polls until the named robot appears or timeout
- `find_by_capability(cap, timeout:)` — browses the capability-specific DNS subtype
- `list_capabilities(timeout:)` — returns sorted unique capability strings across all visible robots
- `dns_label(capability)` — normalises a capability string to a valid DNS label (`"Web Search"` → `"web-search"`)
- `validate_capabilities!(capabilities)` — coerces to an array of strings; raises `ArgumentError` for a capability containing a comma or with no ASCII letter/digit

**`Advertiser`** (`discovery/advertiser.rb`) — Announces a robot over mDNS. `start(timeout: 5)` spawns a background thread running the zeroconf service, waits for it to announce, and re-raises an error raised while it was starting; `stop(timeout: 5)` tears it down with a bounded join (killing a thread that will not exit), so it never hangs. `started?` is false once the thread has died; `error` holds what killed it. Capabilities are validated in `new`. Each capability is registered as a DNS subtype (`_capability-label._sub._robot-lab._tcp.local.`) enabling capability-filtered browsing.

**`Browser`** (`discovery/browser.rb`) — Wraps `ZeroConf.browse`. Parses raw DNS responses (SRV + TXT records) into `Result` objects, deduplicating by name. `parse_response` is private — do not call directly.

**`TxtRecord`** (`discovery/txt_record.rb`) — Encodes/decodes the DNS TXT payload using short wire keys to conserve UDP packet space:
- `p` = path, `v` = rl_version, `c` = comma-joined capabilities
- `encode` validates capabilities content ≤ 253 bytes (`validate_capabilities_content!`), each string ≤ 255 bytes and total wire size ≤ 1300 bytes (`validate!`)
- `decode` returns `{ path:, rl_version:, capabilities: [...] }` — only the keys present on the wire (no `:capabilities` key when there was no `c=` entry)

**`Result`** (`discovery/result.rb`) — `Data.define(:name, :hostname, :port, :path, :capabilities)`. Has a `url` convenience method (`"http://#{hostname}:#{port}#{path}"` — `path` supplies its own leading slash).

**Constants** (`discovery/constants.rb`) — `RobotLab::Discovery::SERVICE_TYPE = "_robot-lab._tcp.local."` (defined directly on `Discovery`; there is no `Constants` module).

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
- `browse` keeps no cache — each call sends a fresh query and returns only robots that answer, so a robot that crashes without calling `stop` just stops appearing. Other caching mDNS stacks (Bonjour, Avahi) may still hold its records until the 60-second TTL expires.
- Instance names must not contain dots — `zeroconf` raises `ArgumentError` from `Advertiser#start`.
- Capability strings in TXT records are comma-separated in a single field capped at 253 bytes of content. Many short capabilities are fine; very long strings will raise `Discovery::Error` from `Advertiser#start`. A capability containing a comma, or with no ASCII letter or digit, raises `ArgumentError` from `Advertiser.new`.
- `find` polls by calling `browse` in a loop — it is blocking and should not be called on the main thread in production.

## Testing

- Minitest with SimpleCov (branch coverage enabled; minimums enforced in `test/test_helper.rb`: 95% line, 75% branch)
- Output via `Minitest::Reporters::SpecReporter`
- Tests mock zeroconf interactions — no actual mDNS traffic is sent
- Current coverage: 100% line / ~92% branch

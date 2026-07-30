# robot_lab-discovery

Zero-configuration mDNS/DNS-SD robot discovery for [RobotLab](https://github.com/MadBomber/robot_lab) on local networks.

Robots advertise themselves via multicast DNS ([mDNS, RFC 6762](https://www.rfc-editor.org/rfc/rfc6762)) and find each other without any central registry, hardcoded URL, or configuration file. Each robot announces a name, an HTTP path, and a free-form set of *capability* tags; other robots (or any process on the LAN) can browse for all of them, look one up by name, or filter by capability.

```ruby
require "robot_lab/discovery"

# A robot announces itself:
adv = RobotLab::Discovery::Advertiser.new(
  name: "headline", port: 9292, path: "/headline",
  capabilities: ["writing", "research"]
)
adv.start

# Anyone on the LAN can find it:
result = RobotLab::Discovery.find("headline", timeout: 5)
result.url   # => "http://my-server.local:9292/headline"
```

This gem augments `robot_lab-a2a` but has **no dependency on it, and no dependency on core `robot_lab` either** — its only runtime dependency is the pure-Ruby [`zeroconf`](https://rubygems.org/gems/zeroconf) gem. Discovery finds you a URL; you decide what protocol to speak to it (A2A, plain HTTP, anything else).

## Navigation

- [Getting Started](getting_started.md) — installation, advertising a robot, discovering robots, the bundled example
- [How It Works](how_it_works.md) — the mDNS/DNS-SD model this gem builds on, the TXT record wire format, capability subtypes, and the constraints that follow from all of it
- [API Reference](api_reference.md) — every public class and method

## At a Glance

| | |
|---|---|
| **Protocol** | Multicast DNS / DNS-SD (RFC 6762 / RFC 6763), pure Ruby — no Bonjour/Avahi/system daemon |
| **Service type** | `_robot-lab._tcp.local.` |
| **Advertise** | `RobotLab::Discovery::Advertiser.new(name:, port:, path:, capabilities:).start` |
| **Discover** | `RobotLab::Discovery.browse` / `.find` / `.find_by_capability` / `.list_capabilities` |
| **Result** | `RobotLab::Discovery::Result` — `name`, `hostname`, `port`, `path`, `capabilities`, `#url` |
| **Scope** | LAN-only — a single multicast subnet, not routable across the internet |
| **Runtime dependency** | `zeroconf ~> 1.0` only |
| **Optional integration** | Self-registers via `RobotLab.register_extension(:discovery, ...)` when core `robot_lab` is loaded — otherwise usable completely standalone |

## Relationship to Other RobotLab Gems

| Gem | Concern |
|---|---|
| `robot_lab` | Core robots, networks, memory |
| `robot_lab-a2a` | The A2A HTTP+SSE transport protocol *between* robots |
| `robot_lab-discovery` | **Where** the robots are and **what they can do** — addressing and capability taxonomy, not transport |

A typical pairing: use `robot_lab-discovery` to find a robot's URL on the LAN, then hand that URL to `robot_lab-a2a` (or plain `Net::HTTP`, or anything else) to actually talk to it.

## Links

- [RobotLab Core](https://github.com/MadBomber/robot_lab)
- [RubyGems](https://rubygems.org/gems/robot_lab-discovery)
- [GitHub](https://github.com/MadBomber/robot_lab-discovery)
- [Changelog](https://github.com/MadBomber/robot_lab-discovery/blob/main/CHANGELOG.md)

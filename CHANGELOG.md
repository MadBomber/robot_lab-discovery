## [Unreleased]

## [0.1.0] - 2026-05-28

### Added

- `RobotLab::Discovery::Advertiser` — registers a robot as a `_robot-lab._tcp.local.`
  mDNS service in a background thread. Accepts a free-form `capabilities:` array;
  each capability is encoded in the TXT record and registered as a DNS-SD subtype
  (`_research._sub._robot-lab._tcp.local.` etc.) for targeted browsing.
  Supports `start`, `stop`, and `started?`. Sends an mDNS goodbye packet (TTL=0)
  on `stop` to remove the service from peers' caches immediately.
- `RobotLab::Discovery::Browser` — browses `_robot-lab._tcp.local.` via
  `ZeroConf.browse`, parses SRV and TXT records, and returns `Result` objects.
  Provides:
  - `browse(timeout:)` — all robots on the LAN
  - `find(name, timeout:)` — single robot by instance name
  - `find_by_capability(capability, timeout:)` — robots advertising a given
    capability, browsed via the corresponding DNS-SD subtype
  - `list_capabilities(timeout:)` — sorted, deduplicated list of all capability
    terms currently advertised on the LAN
- `RobotLab::Discovery::Result` — immutable `Data`-based value object with
  `name`, `hostname`, `port`, `path`, `capabilities`, and a `url` helper method.
- `RobotLab::Discovery::TxtRecord` — encodes and decodes DNS TXT record arrays.
  Fields: `path=`, `rl_version=`, `capabilities=` (comma-separated).
- `RobotLab::Discovery.dns_label` — normalises a free-form capability string
  into a valid DNS label (downcased, non-alphanumeric runs collapsed to hyphens).
- `RobotLab::Discovery` module with `browse`, `find`, `find_by_capability`, and
  `list_capabilities` convenience class methods. Self-registers as a RobotLab
  extension when the core gem is present.
- `examples/01_basic_usage.rb` — end-to-end demo covering all six operations:
  register with capabilities, browse all, find by name, find by capability,
  list capability inventory, and unregister.

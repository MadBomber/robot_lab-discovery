## [Unreleased]

### Changed

- **`require "robot_lab/discovery"` now requires core `robot_lab`** and always registers the `:discovery` extension. Registration previously happened only when `robot_lab` had been required first.
- **`Advertiser#start` waits for the service to announce** (up to `timeout:` seconds, default `Advertiser::START_TIMEOUT` = 5) and re-raises an error raised on the service thread while it was starting, instead of returning immediately and hiding the failure until `stop`. An error raised after startup is available from the new `Advertiser#error`.
- **`Advertiser.new` validates capabilities** via the new `RobotLab::Discovery.validate_capabilities!`: a capability containing a comma, or with no ASCII letter or digit, raises `ArgumentError`.
- **`TxtRecord.encode` enforces `MAX_CAPABILITIES_CONTENT`** through the new `TxtRecord.validate_capabilities_content!`; an over-long capability list now raises `RobotLab::Discovery::Error` with a message naming the 253-byte capability budget rather than the generic 255-byte string limit.
- **Requires `zeroconf ~> 1.3`** (was `~> 1.0`). The `subtypes:` option this gem passes to `ZeroConf::Service` only exists from zeroconf 1.3.0, so older 1.x releases failed at `Advertiser#start`.

### Fixed

- `Advertiser#stop` no longer hangs when called immediately after `#start`. The join is bounded (`timeout:`, default `Advertiser::STOP_TIMEOUT` = 5) and a service thread that does not exit is killed.
- `Browser.browse` and `Browser.find_by_capability` return `[]` instead of raising `NoMethodError` when `ZeroConf.browse` returns `nil`.
- `examples/01_basic_usage.rb` no longer prints a doubled `.local.local` suffix on hosts whose hostname already ends in `.local`.

## [0.6.1] - 2026-11-19

### Changed

- **Minimum Ruby raised to 4.0.9.** `required_ruby_version` is now `>= 4.0.9` (was `>= 3.2.0`), and a `.ruby-version` file pins development to 4.0.9.
- **Requires `robot_lab ~> 0.6`** (was `~> 0.3.0`). Verified against robot_lab 0.6.1 and ruby_llm 2.2.3; no code changes were needed.

## [0.2.8] - 2026-09-09

Released in lockstep with `robot_lab` core v0.2.8: this gem now resolves the released core gem from RubyGems instead of the local sibling checkout (local-path development remains available via `BUNDLE_GEMFILE=Gemfile.local`). Version moves from 0.2.7.1 to 0.2.8 to rejoin the core lockstep. Also in this release: reek warnings triaged to zero, reek added to the development bundle, and gem lifecycle tasks moved to asgard.

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

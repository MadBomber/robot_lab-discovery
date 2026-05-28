## [Unreleased]

## [0.1.0] - 2026-05-28

### Added

- `RobotLab::Discovery::Advertiser` — wraps `ZeroConf::Service` to register a
  robot as a `_robot-lab._tcp.local.` mDNS service in a background thread.
  Supports `start`, `stop`, and `started?`. Encodes the robot's HTTP path and
  gem version in the TXT record.
- `RobotLab::Discovery::Browser` — browses `_robot-lab._tcp.local.` via
  `ZeroConf.browse`, parses SRV and TXT records, and returns `Result` objects.
  Provides `browse(timeout:)` and `find(name, timeout:)` class methods.
- `RobotLab::Discovery::Result` — immutable `Data`-based value object with
  `name`, `hostname`, `port`, `path`, and a `url` helper method.
- `RobotLab::Discovery::TxtRecord` — encodes and decodes TXT record arrays
  (`path=`, `rl_version=`).
- `RobotLab::Discovery` module with `browse` and `find` convenience class
  methods delegating to `Browser`. Self-registers as a RobotLab extension when
  the core gem is present.
- `examples/01_basic_usage.rb` — end-to-end demo: register two robots, browse
  the LAN, find by name, then unregister.

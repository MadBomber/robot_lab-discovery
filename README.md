# robot_lab-discovery

Zero-configuration mDNS/DNS-SD robot discovery for [RobotLab](https://github.com/MadBomber/robot_lab) on local networks.

Robots advertise themselves via multicast DNS (mDNS, RFC 6762) and find each other without any central registry or hardcoded URLs. Augments `robot_lab-a2a` but has no dependency on it — any transport can use the discovered URL.

## How it works

Each robot registers as a `_robot-lab._tcp.local.` mDNS service. Its HTTP path and gem version are stored in the TXT record. Clients browse the same service type and get back `Result` objects containing name, hostname, port, path, and a ready-to-use URL.

```
Advertiser                        Browser
──────────────────────────────    ──────────────────────────────────────
ZeroConf::Service                 ZeroConf.browse("_robot-lab._tcp.local.")
  instance: "headline"              → parse SRV + TXT records
  host:     my-server.local         → Result(name, hostname, port, path)
  port:     9292                    → result.url  # "http://my-server.local:9292/headline"
  TXT:      path=/headline
```

## Installation

```bash
bundle add robot_lab-discovery
```

Or add to your Gemfile:

```ruby
gem "robot_lab-discovery"
```

### System prerequisites

None beyond Ruby >= 3.2. The `zeroconf` gem is pure Ruby and implements mDNS itself using standard UDP multicast sockets — it does not wrap Bonjour, Avahi, or any system mDNS daemon. A multicast-capable network interface is all that is required, which is standard on any LAN.

## Usage

### Advertising a robot

```ruby
require "robot_lab/discovery"

adv = RobotLab::Discovery::Advertiser.new(
  name:     "headline",   # mDNS instance name — no dots allowed
  port:     9292,
  path:     "/headline",  # stored in TXT record; used by browser to build URL
  hostname: Socket.gethostname
)

adv.start   # begins advertising in a background thread
# ... server runs ...
adv.stop    # sends mDNS goodbye packet; removes from peers' caches
```

### Discovering robots

```ruby
require "robot_lab/discovery"

# All robots on the LAN (blocks for timeout seconds)
results = RobotLab::Discovery.browse(timeout: 3)
results.each { |r| puts r.url }
# => http://my-server.local:9292/headline
# => http://my-server.local:9292/tags

# Find one robot by name (polls until found or timeout)
result = RobotLab::Discovery.find("headline", timeout: 5)
result.url  # => "http://my-server.local:9292/headline"
```

### Connecting after discovery

`Result#url` returns a plain URL string. Wire it to whatever client you use:

```ruby
result = RobotLab::Discovery.find("headline")

# With robot_lab-a2a:
client = A2A.client(url: result.url)
client.send_task(message: A2A::Models::Message.user("Summarise today's news"))

# With Net::HTTP directly:
Net::HTTP.get(URI(result.url))
```

### Result fields

| Field      | Type    | Description |
|------------|---------|-------------|
| `name`     | String  | mDNS instance name (e.g. `"headline"`) |
| `hostname` | String  | Fully-qualified `.local` hostname |
| `port`     | Integer | Port the robot server listens on |
| `path`     | String  | HTTP path to the robot (e.g. `"/headline"`) |
| `url`      | String  | `"http://#{hostname}:#{port}#{path}"` |

## Examples

```bash
bundle exec ruby examples/01_basic_usage.rb
```

Walks through the full lifecycle: register two robots, browse the LAN, find by name, and unregister.

## Architecture

```
lib/robot_lab/discovery/
  constants.rb    # SERVICE_TYPE = "_robot-lab._tcp.local."
  txt_record.rb   # encode/decode TXT record arrays (path, rl_version)
  result.rb       # immutable Data value object
  advertiser.rb   # wraps ZeroConf::Service, runs in a thread
  browser.rb      # wraps ZeroConf.browse, parses DNS responses
```

`RobotLab::Discovery` module exposes `browse` and `find` as class methods delegating to `Browser`. If `RobotLab` is loaded, the gem self-registers as an extension via `RobotLab.register_extension(:discovery, ...)`.

## Relationship to other robot_lab gems

| Gem | Concern |
|-----|---------|
| `robot_lab` | Core robots, networks, memory |
| `robot_lab-a2a` | A2A HTTP+SSE transport protocol |
| `robot_lab-discovery` | **Where** are the robots (mDNS addressing) |

Discovery is intentionally transport-agnostic. It finds a URL; you decide what protocol to speak to it.

## Development

```bash
bundle install
bundle exec rake test     # run the test suite
bin/console               # IRB with the gem loaded
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).

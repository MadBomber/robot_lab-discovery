# robot_lab-discovery

Zero-configuration mDNS/DNS-SD robot discovery for [RobotLab](https://github.com/MadBomber/robot_lab) on local networks.

Robots advertise themselves via multicast DNS (mDNS, RFC 6762) and find each other without any central registry or hardcoded URLs. Augments `robot_lab-a2a` but has no dependency on it — any transport can use the discovered URL.

## How it works

Each robot registers as a `_robot-lab._tcp.local.` mDNS service. Its HTTP path, gem version, and capability taxonomy are stored in the TXT record. Each capability is also registered as a DNS-SD subtype, enabling clients to browse by capability type without enumerating all robots.

```
Advertiser                              Browser
──────────────────────────────────────  ────────────────────────────────────────────
ZeroConf::Service                       ZeroConf.browse("_robot-lab._tcp.local.")
  instance:     "headline"                → parse SRV + TXT
  host:         my-server.local           → Result(name, hostname, port, path,
  port:         9292                                capabilities, url)
  TXT:          path=/headline
                capabilities=writing,research
  subtypes:     _writing._sub._robot-lab._tcp.local.
                _research._sub._robot-lab._tcp.local.

                                        ZeroConf.browse("_research._sub._robot-lab._tcp.local.")
                                          → only research robots
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
  name:         "headline",           # mDNS instance name — no dots allowed
  port:         9292,
  path:         "/headline",          # stored in TXT record
  hostname:     Socket.gethostname,
  capabilities: ["writing", "research"]  # free-form taxonomy terms
)

adv.start   # begins advertising in a background thread
# ... server runs ...
adv.stop    # sends mDNS goodbye packet; removes from peers' caches
```

Capability strings are free-form. They are normalised into valid DNS labels
(`"Web Search"` → `"web-search"`) and registered as DNS-SD subtypes, so peers
can browse for them directly.

### Discovering robots

```ruby
require "robot_lab/discovery"

# All robots on the LAN
results = RobotLab::Discovery.browse(timeout: 3)
results.each { |r| puts "#{r.name}: #{r.url}  caps=#{r.capabilities.join(", ")}" }

# Find one robot by name
result = RobotLab::Discovery.find("headline", timeout: 5)
result.url           # => "http://my-server.local:9292/headline"
result.capabilities  # => ["writing", "research"]

# Find all robots offering a specific capability
researchers = RobotLab::Discovery.find_by_capability("research", timeout: 3)

# List every capability type advertised on the LAN right now
RobotLab::Discovery.list_capabilities(timeout: 3)
# => ["analysis", "coding", "research", "writing"]
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

| Field          | Type          | Description |
|----------------|---------------|-------------|
| `name`         | String        | mDNS instance name (e.g. `"headline"`) |
| `hostname`     | String        | Fully-qualified `.local` hostname |
| `port`         | Integer       | Port the robot server listens on |
| `path`         | String        | HTTP path to the robot (e.g. `"/headline"`) |
| `capabilities` | Array<String> | Capability taxonomy terms advertised by this robot |
| `url`          | String        | `"http://#{hostname}:#{port}#{path}"` |

## Capability taxonomy

Capabilities are free-form strings — there is no enforced registry. Use short,
lowercase, hyphen-separated terms that describe what the robot does, not how it
works. Examples:

```
research      analysis      writing       coding
vision        memory        tool-use      orchestration
web-search    summarisation classification
```

A robot may advertise any number of capabilities. Clients browse by capability
using `find_by_capability`, which targets the DNS-SD subtype directly and avoids
scanning all robots on the network.

`dns_label` is available for normalising arbitrary strings:

```ruby
RobotLab::Discovery.dns_label("Web Search / NLP")  # => "web-search-nlp"
```

## Examples

```bash
bundle exec ruby examples/01_basic_usage.rb
```

Covers all six operations: register with capabilities, browse all, find by name,
find by capability, list capability inventory, and unregister.

## Architecture

```
lib/robot_lab/discovery/
  constants.rb    # SERVICE_TYPE = "_robot-lab._tcp.local."
  txt_record.rb   # encode/decode TXT record arrays (path, rl_version, capabilities)
  result.rb       # immutable Data value object (name, hostname, port, path, capabilities)
  advertiser.rb   # wraps ZeroConf::Service, runs in a thread, registers subtypes
  browser.rb      # wraps ZeroConf.browse, parses DNS responses
```

`RobotLab::Discovery` module exposes `browse`, `find`, `find_by_capability`, and
`list_capabilities` as class methods. If `RobotLab` is loaded, the gem
self-registers as an extension via `RobotLab.register_extension(:discovery, ...)`.

## Relationship to other robot_lab gems

| Gem | Concern |
|-----|---------|
| `robot_lab` | Core robots, networks, memory |
| `robot_lab-a2a` | A2A HTTP+SSE transport protocol |
| `robot_lab-discovery` | **Where** are the robots and **what can they do** (mDNS addressing + capability taxonomy) |

Discovery is intentionally transport-agnostic. It finds a URL; you decide what
protocol to speak to it.

## Development

```bash
bundle install
bundle exec rake test     # run the test suite
bin/console               # IRB with the gem loaded
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).

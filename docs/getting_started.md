# Getting Started

## Prerequisites

- Ruby 3.2+ (per the gemspec's `required_ruby_version`)
- A multicast-capable network interface — standard on any LAN. `zeroconf` is pure Ruby and implements mDNS itself over standard UDP multicast sockets; it does not wrap Bonjour, Avahi, or any system mDNS daemon, so there is nothing else to install.
- No dependency on core `robot_lab` — this gem works completely standalone. If `RobotLab` (core) happens to be loaded, `robot_lab-discovery` self-registers as an extension via `RobotLab.register_extension(:discovery, ...)`; if it isn't, nothing changes.

## Installation

```sh
bundle add robot_lab-discovery
```

Or add to your `Gemfile` directly:

```ruby
gem "robot_lab-discovery"
```

Then:

```sh
bundle install
```

## Advertising a Robot

```ruby
require "robot_lab/discovery"

adv = RobotLab::Discovery::Advertiser.new(
  name:         "headline",              # mDNS instance name — no dots allowed
  port:         9292,
  path:         "/headline",             # stored in the TXT record
  hostname:     Socket.gethostname,      # default; override for multi-homed hosts
  capabilities: ["writing", "research"]  # free-form taxonomy terms
)

adv.start   # begins advertising in a background thread
# ... your server runs ...
adv.stop    # sends an mDNS goodbye packet (TTL=0); removes it from peers' caches
```

`start` spawns the actual `ZeroConf::Service` on a background `Thread` and returns `self` immediately — it does not block your server's main thread. `stop` joins that thread before returning, so it's safe to assume the service is fully torn down once `stop` returns.

Capability strings are free-form — see [How It Works — Capability Taxonomy](how_it_works.md#capability-taxonomy) for the (light) conventions worth following. Each one is normalized into a valid DNS label (`"Web Search"` → `"web-search"`) and registered as a DNS-SD subtype, so peers can browse for it directly without scanning every robot on the network.

## Discovering Robots

```ruby
require "robot_lab/discovery"

# All robots on the LAN
results = RobotLab::Discovery.browse(timeout: 3)
results.each { |r| puts "#{r.name}: #{r.url}  caps=#{r.capabilities.join(', ')}" }

# Find one robot by name (polls until found or timeout)
result = RobotLab::Discovery.find("headline", timeout: 5)
result.url            # => "http://my-server.local:9292/headline"
result.capabilities   # => ["writing", "research"]

# Find all robots offering a specific capability
researchers = RobotLab::Discovery.find_by_capability("research", timeout: 3)

# List every capability type currently advertised on the LAN
RobotLab::Discovery.list_capabilities(timeout: 3)
# => ["analysis", "coding", "research", "writing"]
```

All four are blocking calls — each one waits (up to `timeout` seconds) for mDNS responses to arrive over the network before returning. None of them should be called from a request thread that needs to stay responsive; see [Key Constraints](#key-constraints) below.

## Connecting After Discovery

`Result#url` is a plain URL string — wire it to whatever client you use:

```ruby
result = RobotLab::Discovery.find("headline")

# With robot_lab-a2a:
client = A2A.client(url: result.url)
client.send_task(message: A2A::Models::Message.user("Summarise today's news"))

# With Net::HTTP directly:
Net::HTTP.get(URI(result.url))
```

## Running the Bundled Example

`examples/01_basic_usage.rb` walks through the complete lifecycle end to end — registering three robots with different capabilities, browsing all of them, finding one by name, finding by capability, listing the capability inventory, then unregistering:

```sh
bundle exec ruby examples/01_basic_usage.rb
```

Both the advertisers and the browser run in the same process in that example purely for demo convenience — in production, each robot's own server process runs its own `Advertiser`, and any separate process (a dashboard, an orchestrator, another robot) does the browsing.

## Development

```sh
bundle install
bundle exec rake test     # run the test suite (Minitest::Reporters::SpecReporter output)
bin/console                # IRB with the gem loaded
```

Tests mock the `zeroconf` interactions (`ZeroConf.stub(:browse, ...)`) — no actual mDNS traffic is sent while running the suite.

## Key Constraints

- **mDNS is LAN-only.** It works within a single multicast subnet — it does not cross routers, VPN tunnels, or cloud network boundaries. There is no equivalent of this gem for discovery across separate networks.
- **`find` and `browse` can return stale results.** If a robot's process crashes without calling `Advertiser#stop`, its mDNS records are only removed once their TTL expires on peers' caches — there's no guaranteed instant removal in that failure path (only the graceful-shutdown goodbye packet from `stop` is instant).
- **`find` polls in a blocking loop.** It repeatedly calls `browse` internally until the named robot appears or `timeout` elapses — see [How It Works — `find(name, timeout:)`](how_it_works.md#findname-timeout). Don't call it from a thread (a web request handler, an event loop) that needs to stay responsive.
- **Capability content is capped.** All capabilities for one robot are joined into a single comma-separated TXT string capped at 253 bytes of content (`TxtRecord::MAX_CAPABILITIES_CONTENT`). Many short capability names comfortably fit; very long strings or a huge number of them will raise `RobotLab::Discovery::Error` at `Advertiser#start` (via `TxtRecord.encode`/`validate!`) — see [How It Works](how_it_works.md#the-txt-record-wire-format) for the exact limits.
- **Instance names may not contain dots.** `name:` becomes the mDNS instance name; DNS-SD instance names are dot-separated internally (`name._robot-lab._tcp.local.`), so a `name:` containing a literal `.` will produce a malformed or ambiguous service name.

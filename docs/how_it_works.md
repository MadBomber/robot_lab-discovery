# How It Works

## The mDNS/DNS-SD Model

This gem is a thin, purpose-built layer over two RFCs:

- **mDNS** ([RFC 6762](https://www.rfc-editor.org/rfc/rfc6762)) — DNS queries and responses sent over UDP multicast on the local subnet (`224.0.0.251:5353`), instead of to a unicast DNS server. Any host on the same LAN segment hears every query and response.
- **DNS-SD** ([RFC 6763](https://www.rfc-editor.org/rfc/rfc6763)) — a convention for naming *services* within DNS: a service type (`_robot-lab._tcp.local.`), an instance name, and a TXT record carrying arbitrary key/value metadata alongside the usual SRV record (which carries the target host and port).

`RobotLab::Discovery::Constants::SERVICE_TYPE` is `"_robot-lab._tcp.local."` — every robot advertised by this gem, regardless of name or capabilities, registers under that one DNS-SD service type. A browser listening for that type hears every robot on the LAN; capability-specific browsing (below) narrows that with DNS-SD *subtypes* instead of a second protocol.

The `zeroconf` gem (this gem's only runtime dependency) implements both RFCs itself in pure Ruby over a raw UDP socket — there is no Bonjour/Avahi/system daemon involved and nothing to install beyond the gem itself.

## Advertising: `Advertiser`

```ruby
adv = RobotLab::Discovery::Advertiser.new(name:, port:, path:, hostname: Socket.gethostname, capabilities: [])
adv.start
```

`start` builds a `ZeroConf::Service` for `SERVICE_TYPE` with:

- `instance_name:` — the `name:` you gave (becomes the DNS-SD instance name)
- `text:` — the TXT record, built by `TxtRecord.encode(path:, capabilities:)` (see below)
- `subtypes:` — one `"_#{dns_label(capability)}"` string per capability

...then spawns `@service.start` on a background `Thread` and returns `self` immediately, so `start` never blocks the caller. `stop` calls `@service.stop` (which sends the mDNS *goodbye* packet — a response with TTL=0 telling every listening peer to drop this record from its cache right away) and then `@thread.join`, so by the time `stop` returns, the advertising thread has fully exited. `started?` reports `@thread&.alive? || false`.

### Subtypes: How Capability Browsing Actually Works

DNS-SD subtypes are a real part of the spec, not something this gem invents: a service can register as belonging to `_robot-lab._tcp.local.` **and** to any number of `_<subtype>._sub._robot-lab._tcp.local.` names simultaneously. `Advertiser#start` registers one subtype per capability — a robot advertising `["writing", "research"]` shows up under:

```
_robot-lab._tcp.local.                          (always)
_writing._sub._robot-lab._tcp.local.
_research._sub._robot-lab._tcp.local.
```

`Discovery.find_by_capability("research")` browses `_research._sub._robot-lab._tcp.local.` directly — the mDNS query itself only reaches robots registered under that subtype, so this is a real network-level filter, not a client-side filter over every robot's TXT record. `Discovery.browse`/`list_capabilities`, by contrast, browse the base `_robot-lab._tcp.local.` type and see every robot regardless of capability.

## The TXT Record Wire Format

`TxtRecord` encodes three possible fields into the DNS TXT record, using single-character keys to conserve UDP packet space:

| Wire key | Meaning | Long-form equivalent avoided |
|---|---|---|
| `p` | `path` | `path=` (saves 3 bytes) |
| `v` | `rl_version` (the gem's `VERSION` at encode time) | `rl_version=` (saves 9 bytes) |
| `c` | `capabilities`, comma-joined | `capabilities=` (saves 11 bytes) |

`encode(path:, capabilities: [])` always includes `p=` and `v=`; `c=` is omitted entirely when `capabilities` is empty (not encoded as `c=`). `decode(strings)` reverses this, splitting each `"key=value"` string on the *first* `=` only (so a path containing `=` round-trips correctly — `"p=/foo=bar"` decodes to `path: "/foo=bar"`), and silently ignores any key it doesn't recognize (forward-compatible with future fields). `capabilities` is only present in the decoded hash when a `c=` entry existed at all — `decode(["p=/x"])` returns a hash with no `:capabilities` key, not `capabilities: []`; `Browser#parse_response` is what supplies the `[]` default via `txt.fetch(:capabilities, [])` when building a `Result`.

### Size Limits, and Why They Exist

Two limits are enforced by `TxtRecord.validate!`, called from inside `encode`:

1. **Per-string: 255 bytes** (`MAX_STRING_BYTES`). This isn't a design choice — it's RFC 1035 §3.3.14: every string inside a TXT record is length-prefixed with a single byte, so no individual string can exceed 255 bytes no matter what. Since capabilities all share one `c=...` string, `MAX_CAPABILITIES_CONTENT` (`255 - "c".bytesize - "=".bytesize` = **253** bytes) is the real budget for however many comma-separated capability names you pack in.
2. **Total wire size: 1300 bytes** (`MAX_TOTAL_BYTES`). This one *is* a design choice, derived from the physical network: mDNS runs over UDP, and a standard Ethernet MTU (1500 bytes) minus IP/UDP/DNS header overhead leaves roughly 1472 bytes for the whole DNS payload. After the SRV and A/AAAA records that accompany every service announcement also claim space in that same packet, keeping the TXT record itself under 1300 bytes (wire size = 1 length-prefix byte + content bytes, summed across every string) leaves enough headroom that the whole announcement stays inside a single unfragmented UDP packet. `encode` alone can never actually reach this second limit — three strings, each capped at 255 bytes, tops out well under 1300 — so this check exists to protect callers who build TXT string arrays some other way and hand them to `validate!` directly, not a realistic failure mode of `encode` itself.

Both violations raise `RobotLab::Discovery::Error` with a message naming the exact byte count, at `Advertiser#start` time (since that's when `TxtRecord.encode` runs) — not at `Advertiser.new` time, since `capabilities:` is only assigned, not encoded, in the constructor.

## Discovering: `Browser`

`Browser` is a module of class methods — there's no instance to hold, since browsing is stateless per call.

#### `browse(timeout:)`

Calls `ZeroConf.browse(SERVICE_TYPE, timeout:)`, which blocks for up to `timeout` seconds collecting raw mDNS responses, then maps each one through the private `parse_response` and drops any that come back `nil` (`filter_map`), then deduplicates by `name` (`uniq(&:name)` — a robot that responds more than once during the browse window, which is normal for mDNS, only appears once in the result).

#### `find(name, timeout:)`

```ruby
deadline = Time.now + timeout
loop do
  remaining = deadline - Time.now
  return nil if remaining <= 0
  result = browse(timeout: [remaining, 1].min).find { |r| r.name == name }
  return result if result
end
```

This is a **polling loop**, not a single `browse` call with a longer timeout: it repeatedly calls `browse` in increments of at most 1 second (`[remaining, 1].min`), checking after each one whether the named robot showed up, until either it's found or the overall `timeout` has elapsed. The 1-second cap keeps each individual `browse` responsive rather than committing the whole remaining budget to one blocking call; the practical effect is that `find` can return as soon as the target robot answers, rather than always waiting out the full `timeout`.

#### `find_by_capability(capability, timeout:)`

Normalizes `capability` via `RobotLab::Discovery.dns_label`, browses `"_#{label}._sub.#{SERVICE_TYPE}"` — the DNS-SD subtype, not the base service type — and otherwise behaves exactly like `browse` (parse, filter, dedupe by name).

#### `list_capabilities(timeout:)`

`browse(timeout:).flat_map(&:capabilities).uniq.sort` — every capability string across every currently-visible robot, deduplicated and alphabetically sorted.

#### `parse_response(response)` *(private)*

Given a raw `Resolv::DNS::Message`-like response, walks `response.answer + response.additional` looking for an `SRV` record (supplies `port`, `hostname` — with the trailing `.` FQDN dot stripped — and the instance name, taken from the first label of the resource name) and a `TXT` record (decoded via `TxtRecord.decode`). If either the SRV data or a `path` from the TXT data is missing, it returns `nil` rather than raising — a malformed or partial mDNS response is simply skipped, not an error condition, which is why `browse` uses `filter_map` rather than `map`.

## `RobotLab::Discovery::Result`

```ruby
Result = Data.define(:name, :hostname, :port, :path, :capabilities) do
  def url = "http://#{hostname}:#{port}#{path}"
end
```

An immutable value object (Ruby's `Data.define`, not a mutable `Struct` or hash) — every `Result` a `browse`/`find`/`find_by_capability` call returns is a fresh, frozen snapshot; there's no way to accidentally mutate one and have it silently affect a cache. `url` always assumes plain `http://` — this gem has no notion of TLS and doesn't encode a scheme in the TXT record; if a robot actually serves over HTTPS, build the URL yourself from the other fields rather than using `#url` directly.

## `dns_label`

```ruby
def self.dns_label(capability)
  capability.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
end
```

Downcases, collapses every run of non-alphanumeric characters to a single hyphen, then strips any leading/trailing hyphen left over. `"Web Search"` → `"web-search"`; `"NLP/Analysis"` → `"nlp-analysis"`; `"Web Search / NLP"` → `"web-search-nlp"` (the `/` and surrounding spaces all collapse into the hyphens already produced by the spaces around them). This is what turns a free-form capability string into something legal to use as a DNS label component in a subtype name — DNS labels can't contain arbitrary punctuation, spaces, or mixed case in a way every resolver treats consistently.

## Capability Taxonomy

Capabilities are entirely free-form strings — there is no enforced registry or fixed vocabulary anywhere in this gem. The convention (not an enforced rule) is short, lowercase, hyphen-separated terms describing *what* a robot does, not *how* it works internally — e.g. `research`, `analysis`, `writing`, `coding`, `vision`, `memory`, `tool-use`, `orchestration`, `web-search`, `summarisation`, `classification`. A robot can advertise any number of them; each becomes its own DNS-SD subtype (see above), so clients browsing by capability only ever hear from robots that actually advertise it — no client-side filtering of the full robot list is needed.

## Errors

`RobotLab::Discovery::Error` (a plain `StandardError` subclass) is raised in exactly one place in this gem: `TxtRecord.validate!`, when either the per-string or total wire-size limit is exceeded (see above). There's no other error class in the gem — `Advertiser`/`Browser` let any underlying `zeroconf`/`Resolv`/socket error propagate as-is rather than wrapping it.

## Key Constraints (and Why)

These follow directly from the mechanics above, not from arbitrary gem-level restrictions:

- **LAN-only, by protocol, not by choice.** mDNS multicast packets don't cross routers (that's what makes them "local" — RFC 6762 explicitly scopes them to the local link). There is no configuration in this gem that extends reach beyond a single multicast subnet; a VPN, a different VLAN, or a cloud network boundary will not see these announcements at all.
- **Stale results after an ungraceful crash.** `Advertiser#stop` sends an explicit goodbye packet that tells peers to evict the record immediately. A process that dies without calling `stop` (a kill -9, a crash) never sends that packet — its record simply sits in every peer's cache until that record's normal mDNS TTL expires on its own. `browse`/`find` have no way to distinguish "still running" from "crashed, TTL not yet expired" — a caller that needs liveness guarantees beyond "recently advertised" needs a mechanism this gem doesn't provide (e.g. an application-level heartbeat over whatever transport the discovered URL leads to).
- **`find` blocks the calling thread.** It's a real polling loop (see above), not instant — even a successful lookup can take up to ~1 second (one polling increment) after the robot actually answers, and an unsuccessful one blocks for the *entire* `timeout`. Never call it from a thread that has to stay responsive (a web request handler, an event loop's main thread) without moving it to a background thread or job yourself.
- **Capability content is capped by the RFC 1035 per-string limit**, not an arbitrary choice this gem made — see [Size Limits](#size-limits-and-why-they-exist) above for the exact numbers and where they come from.

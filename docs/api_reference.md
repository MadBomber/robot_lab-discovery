# API Reference

Every public class, module, and method in `robot_lab-discovery`. See [How It Works](how_it_works.md) for the concepts and wire-level detail behind each one.

## `RobotLab::Discovery` (module)

Top-level convenience methods — thin delegators to `Browser`, plus two standalone utility methods.

### `browse(timeout: 3) → Array<Result>`

All robots currently visible on the LAN, deduplicated by name. Delegates to `Browser.browse`.

```ruby
RobotLab::Discovery.browse(timeout: 3).each { |r| puts r.url }
```

### `find(name, timeout: 5) → Result, nil`

Polls (see [How It Works](how_it_works.md#findname-timeout)) until a robot named `name` appears or `timeout` elapses. Returns `nil` if it never appears. Delegates to `Browser.find`.

### `find_by_capability(cap, timeout: 3) → Array<Result>`

Robots advertising capability `cap`, found by browsing that capability's DNS-SD subtype directly (a real network-level filter, not client-side). Delegates to `Browser.find_by_capability`.

### `list_capabilities(timeout: 3) → Array<String>`

Every capability string currently advertised by any robot on the LAN, exactly as advertised (not `dns_label`-normalized), deduplicated and sorted (Ruby's default case-sensitive `String` order). Delegates to `Browser.list_capabilities`.

### `dns_label(capability) → String`

Normalizes a free-form capability string into a valid DNS label: downcased, non-alphanumeric runs collapsed to a single hyphen, no leading/trailing hyphen.

```ruby
RobotLab::Discovery.dns_label("Web Search")        # => "web-search"
RobotLab::Discovery.dns_label("NLP/Analysis")      # => "nlp-analysis"
RobotLab::Discovery.dns_label("Web Search / NLP")  # => "web-search-nlp"
```

### `validate_capabilities!(capabilities) → Array<String>`

Coerces `capabilities` (an array, a single value, or `nil`) to an array of strings and returns it. Raises `ArgumentError` if any capability contains a comma (it would be split in two when the TXT record is decoded) or contains no ASCII letter or digit (its `dns_label` would be empty). Called by `Advertiser.new`.

```ruby
RobotLab::Discovery.validate_capabilities!(%i[research writing])  # => ["research", "writing"]
RobotLab::Discovery.validate_capabilities!(["a,b"])               # raises ArgumentError
```

### `Error`

`RobotLab::Discovery::Error < StandardError` — raised only by `TxtRecord.validate!` and `TxtRecord.validate_capabilities_content!` (see below) when a TXT record exceeds its size limits.

### Constants

| Constant | Value | Meaning |
|---|---|---|
| `SERVICE_TYPE` | `"_robot-lab._tcp.local."` | the one DNS-SD service type every robot registers under, regardless of name or capabilities |
| `VERSION` | `"0.6.1"` | the gem version; also written into every TXT record as `v=` |

```ruby
RobotLab::Discovery::SERVICE_TYPE  # => "_robot-lab._tcp.local."
```

---

## `RobotLab::Discovery::Advertiser`

Announces one robot over mDNS.

### `new(name:, port:, path:, hostname: Socket.gethostname, capabilities: [])`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `String` | *(required)* | mDNS instance name. Must not contain dots — not checked here, but `#start` raises `ArgumentError` (from `zeroconf`) if it does. |
| `port` | `Integer` | *(required)* | port the robot's server listens on |
| `path` | `String` | *(required)* | HTTP path to the robot; stored in the TXT record, not validated by this gem |
| `hostname` | `String` | `Socket.gethostname` | the host name to advertise as the SRV target; `zeroconf` strips any trailing `.local` and advertises `"<hostname>.local."` |
| `capabilities` | `Array<String>`, `String` | `[]` | free-form taxonomy terms; coerced to an array of strings and checked by `Discovery.validate_capabilities!` — raises `ArgumentError` for one that contains a comma or has no ASCII letter or digit |

Only validates `capabilities` and assigns instance variables — no network activity happens until `#start` is called.

### Constants

| Constant | Value | Meaning |
|---|---|---|
| `START_TIMEOUT` | `5` | default seconds `#start` waits for the service thread to announce or fail |
| `STOP_TIMEOUT` | `5` | default seconds `#stop` waits for the service thread to exit before killing it |

### `start(timeout: START_TIMEOUT) → self`

Builds a `ZeroConf::Service` for `SERVICE_TYPE`, encoding `path:`/`capabilities:` into the TXT record via `TxtRecord.encode` (raises `RobotLab::Discovery::Error` here if the record is too large — see [How It Works](how_it_works.md#size-limits-and-why-they-exist)) and registering one DNS-SD subtype per capability. Spawns the actual service on a background `Thread`, then waits until it has sent its announcement, has finished, or `timeout` seconds have passed (normally a few milliseconds) and returns `self`. An error raised on that thread while the service is starting is re-raised here (and kept in `#error`); `zeroconf`'s `ArgumentError` for a dotted `name:` is raised here too.

### `stop(timeout: STOP_TIMEOUT) → self`

Stops the `ZeroConf::Service` (sends an mDNS goodbye packet, TTL=0) and joins the background thread for at most `timeout` seconds; a thread that still has not exited is killed and joined again for up to `timeout` seconds, so `stop` never blocks indefinitely — including when called immediately after `start`. By the time `stop` returns, advertising has ended. Safe to call when not started.

### `started? → Boolean`

`true` while the background thread is alive; `false` before `start`, after `stop`, or once the thread has died from an error (see `#error`).

### Attributes

`name`, `port`, `path`, `hostname`, `capabilities` — all readers, reflecting the values passed to `new` (`capabilities` after coercion to an array of strings).

`error` — the `StandardError` that ended the background thread, or `nil`. Reset to `nil` by each `start`.

---

## `RobotLab::Discovery::Browser` (module)

Stateless class methods that do the actual mDNS browsing and response parsing. `RobotLab::Discovery.browse`/`find`/`find_by_capability`/`list_capabilities` are thin delegators to these.

### `browse(timeout: 3) → Array<Result>`

`ZeroConf.browse(SERVICE_TYPE, timeout:)`, parsed into `Result`s, deduplicated by `name`. Always returns an array — `[]` when `zeroconf` hands back `nil`.

### `find(name, timeout: 5) → Result, nil`

Polls `browse` in ≤1-second increments until `name` matches or `timeout` elapses; `nil` on timeout. See [How It Works](how_it_works.md#findname-timeout) for why this is a real loop, not a single call.

### `find_by_capability(capability, timeout: 3) → Array<Result>`

Browses `"_#{dns_label(capability)}._sub.#{SERVICE_TYPE}"` instead of the base service type.

### `list_capabilities(timeout: 3) → Array<String>`

`browse(timeout:).flat_map(&:capabilities).uniq.sort` — a plain case-sensitive `String` sort of the capability strings as advertised.

### `parse_response(response)` *(private — not part of the public API)*

Extracts SRV (`port`, `hostname`, instance name) and TXT (`path`, `capabilities`) data from a raw mDNS response and builds a `Result`. Returns `nil` for a malformed/partial response (missing SRV or missing `path`) rather than raising — this is why callers use `filter_map`, not `map`. Documented here only because `CLAUDE.md` calls it out explicitly: **do not call this directly**; it's an implementation detail of `browse`/`find_by_capability`.

---

## `RobotLab::Discovery::Result`

```ruby
Result = Data.define(:name, :hostname, :port, :path, :capabilities)
```

An immutable value object — every field below is a plain reader; there are no writers. Defined directly under `RobotLab::Discovery` with a `url` method added in the `Data.define` block.

| Field | Type | Description |
|---|---|---|
| `name` | `String` | mDNS instance name |
| `hostname` | `String` | fully-qualified `.local` hostname (trailing DNS root dot already stripped) |
| `port` | `Integer` | port the robot's server listens on |
| `path` | `String` | HTTP path to the robot |
| `capabilities` | `Array<String>` | capability taxonomy terms this robot advertises (`[]` if none) |

#### `url → String`

`"http://#{hostname}:#{port}#{path}"`. Always plain HTTP — this gem has no notion of a scheme beyond that; build the URL yourself if a robot serves over HTTPS.

---

## `RobotLab::Discovery::TxtRecord` (module)

Encodes/decodes the DNS TXT record payload. Normally used internally by `Advertiser`/`Browser`; documented publicly because the wire format and size limits are useful to understand when debugging a discovery issue or building a compatible advertiser in another language.

### Constants

| Constant | Value | Meaning |
|---|---|---|
| `PATH_KEY` | `"p"` | wire key for the HTTP path |
| `VERSION_KEY` | `"v"` | wire key for the gem's version at encode time |
| `CAPABILITIES_KEY` | `"c"` | wire key for the comma-joined capability list |
| `MAX_STRING_BYTES` | `255` | RFC 1035 §3.3.14 per-string limit — not configurable |
| `MAX_TOTAL_BYTES` | `1300` | wire-size budget kept under the UDP/Ethernet MTU to avoid fragmentation |
| `MAX_CAPABILITIES_CONTENT` | `253` | bytes available for the capabilities string's content (`255 - "c".bytesize - "=".bytesize`) |

### `encode(path:, capabilities: []) → Array<String>`

Builds `["p=#{path}", "v=#{VERSION}"]`, appending `"c=#{capabilities.join(',')}"` only when `capabilities` is non-empty, then validates the result via `validate!` (raising `RobotLab::Discovery::Error` on a size violation) before returning it. The comma-joined capabilities are checked first by `validate_capabilities_content!`.

### `validate_capabilities_content!(content) → String`

Raises `RobotLab::Discovery::Error` if `content` (the comma-joined capability list, without its `c=` key) is larger than `MAX_CAPABILITIES_CONTENT` bytes; returns `content` unchanged otherwise. Called internally by `encode`.

### `decode(strings) → Hash`

Parses an array of `"key=value"` strings (splitting on the *first* `=` only, so a value itself containing `=` round-trips correctly) into `{path:, rl_version:, capabilities:}`. Unknown keys are silently ignored. `:capabilities` is only present in the returned hash when a `c=` entry existed — absent, not `[]`, when there wasn't one.

### `validate!(strings) → Array<String>`

Raises `RobotLab::Discovery::Error` if any single string exceeds `MAX_STRING_BYTES`, or if the total wire size (`sum of (1 + bytesize)` across all strings, accounting for each string's length-prefix byte) exceeds `MAX_TOTAL_BYTES`. Returns `strings` unchanged when valid. Called internally by `encode`; exposed publicly for callers who build TXT string arrays some other way.

---

## Extension registration

`require "robot_lab/discovery"` requires core `robot_lab` and calls `RobotLab.register_extension(:discovery, RobotLab::Discovery)`, so `RobotLab.extension_loaded?(:discovery)` returns `true` regardless of require order.

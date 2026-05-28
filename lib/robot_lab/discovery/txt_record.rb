# frozen_string_literal: true

module RobotLab
  module Discovery
    module TxtRecord
      # Short wire keys — every byte saved is more room for capability names.
      #   p  = path          (vs "path="         — saves 3 bytes)
      #   v  = rl_version    (vs "rl_version="   — saves 9 bytes)
      #   c  = capabilities  (vs "capabilities=" — saves 11 bytes)
      PATH_KEY         = "p"
      VERSION_KEY      = "v"
      CAPABILITIES_KEY = "c"

      # RFC 1035 §3.3.14: each string in a TXT record is length-prefixed with
      # one byte, so the content of any single string is capped at 255 bytes.
      MAX_STRING_BYTES = 255

      # mDNS runs over UDP. Ethernet MTU (1500) minus IP/UDP/DNS headers leaves
      # ~1472 bytes for the DNS payload. After accounting for the SRV, A/AAAA,
      # and PTR records that accompany a service announcement, the TXT record
      # wire size (1 length-prefix byte per string + content bytes) should stay
      # under 1300 bytes to fit in a single unfragmented packet.
      MAX_TOTAL_BYTES = 1300

      # Bytes available for capability names + commas after key + "=" overhead.
      MAX_CAPABILITIES_CONTENT = MAX_STRING_BYTES - CAPABILITIES_KEY.bytesize - 1  # 253

      def self.encode(path:, capabilities: [])
        record = [
          "#{PATH_KEY}=#{path}",
          "#{VERSION_KEY}=#{VERSION}",
        ]
        record << "#{CAPABILITIES_KEY}=#{Array(capabilities).join(",")}" unless Array(capabilities).empty?
        validate!(record)
        record
      end

      def self.decode(strings)
        strings.each_with_object({}) do |entry, hash|
          k, v = entry.split("=", 2)
          next unless k && v
          case k
          when PATH_KEY         then hash[:path]         = v
          when VERSION_KEY      then hash[:rl_version]   = v
          when CAPABILITIES_KEY then hash[:capabilities] = v.split(",")
          end
        end
      end

      def self.validate!(strings)
        strings.each do |s|
          if s.bytesize > MAX_STRING_BYTES
            raise Error,
              "TXT record string exceeds #{MAX_STRING_BYTES} bytes " \
              "(#{s.bytesize} bytes): #{s[0, 40].inspect}#{"..." if s.length > 40}"
          end
        end

        # Wire size: each string occupies 1 length-prefix byte + its content.
        wire_size = strings.sum { |s| 1 + s.bytesize }
        if wire_size > MAX_TOTAL_BYTES
          raise Error,
            "TXT record wire size exceeds #{MAX_TOTAL_BYTES} bytes (#{wire_size} bytes). " \
            "Shorten path or reduce the number/length of capabilities."
        end

        strings
      end
    end
  end
end

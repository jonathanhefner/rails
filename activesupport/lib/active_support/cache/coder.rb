# frozen_string_literal: true

require_relative "entry"

module ActiveSupport
  module Cache
    class Coder # :nodoc:
      def initialize(serializer, compressor, legacy_serializer: false)
        @serializer = serializer
        @compressor = compressor
        @legacy_serializer = legacy_serializer
      end

      def dump(entry)
        return @serializer.dump(entry) if @legacy_serializer

        dump_compressed(entry, Float::INFINITY)
      end

      def dump_compressed(entry, threshold)
        return @serializer.dump_compressed(entry, threshold) if @legacy_serializer

        # If value is a string with a supported encoding, use it as the payload
        # instead of passing it through the serializer.
        if type = type_for_string(entry.value)
          payload = binary_compatible_string(entry.value)
        else
          type = OBJECT_DUMP_TYPE
          payload = serialize(entry.value)
        end

        # Compress payload if it meets the size threshold. (Note that `type < 0`
        # signifies a compressed payload with `type.abs` as its actual type.)
        if compressed = try_compress(payload, threshold)
          payload = compressed
          type = -type
        end

        expires_at = entry.expires_at || -1.0

        version = dump_version(entry.version)
        version_length = version&.bytesize || -1

        packed = [SIGNATURE, type, expires_at, version_length].pack(PACKED_TEMPLATE)
        packed << version if version
        packed << payload
      end

      def load(dumped)
        return @serializer.load(dumped) if !signature?(dumped)

        type = dumped.unpack1(PACKED_TYPE_TEMPLATE)
        expires_at = dumped.unpack1(PACKED_EXPIRES_AT_TEMPLATE)
        version_length = dumped.unpack1(PACKED_VERSION_LENGTH_TEMPLATE)

        expires_at = nil if expires_at < 0
        version = load_version(dumped.byteslice(PACKED_VERSION_INDEX, version_length))
        payload = dumped.byteslice((PACKED_VERSION_INDEX + [version_length, 0].max)..)

        payload = decompress(payload) if type < 0

        if string_encoding = STRING_ENCODINGS[type.abs]
          value = payload.force_encoding(string_encoding)
        else
          value = deserialize(payload)
        end

        Cache::Entry.new(value, version: version, expires_at: expires_at)
      end

      private
        SIGNATURE = "\x00\x11".b.freeze

        OBJECT_DUMP_TYPE = 0x01

        STRING_ENCODINGS = {
          0x02 => Encoding::UTF_8,
          0x03 => Encoding::BINARY,
          0x04 => Encoding::US_ASCII,
        }

        PACKED_TEMPLATE = "A#{SIGNATURE.bytesize}cEl<"
        PACKED_TYPE_TEMPLATE = "@#{SIGNATURE.bytesize}c"
        PACKED_EXPIRES_AT_TEMPLATE = "@#{[0].pack(PACKED_TYPE_TEMPLATE).bytesize}E"
        PACKED_VERSION_LENGTH_TEMPLATE = "@#{[0].pack(PACKED_EXPIRES_AT_TEMPLATE).bytesize}l<"
        PACKED_VERSION_INDEX = [0].pack(PACKED_VERSION_LENGTH_TEMPLATE).bytesize

        MARSHAL_SIGNATURE = "\x04\x08".b.freeze

        def signature?(dumped)
          dumped.is_a?(String) && dumped.start_with?(SIGNATURE)
        end

        def type_for_string(value)
          STRING_ENCODINGS.key(value.encoding) if value.instance_of?(String)
        end

        def binary_compatible_string(string)
          (string.encoding == Encoding::BINARY || string.ascii_only?) ? string : string.b
        end

        def serialize(value)
          @serializer.dump(value)
        end

        def deserialize(serialized)
          @serializer.load(serialized)
        end

        def try_compress(string, threshold)
          if string.bytesize >= threshold
            compressed = @compressor.deflate(string)
            compressed if compressed.bytesize < string.bytesize
          end
        end

        def decompress(compressed)
          @compressor.inflate(compressed)
        end

        def dump_version(version)
          if version
            if version.encoding != Encoding::UTF_8 || version.start_with?(MARSHAL_SIGNATURE)
              Marshal.dump(version)
            else
              binary_compatible_string(version)
            end
          end
        end

        def load_version(dumped_version)
          if dumped_version
            if dumped_version.start_with?(MARSHAL_SIGNATURE)
              Marshal.load(dumped_version)
            else
              dumped_version.force_encoding(Encoding::UTF_8)
            end
          end
        end
    end
  end
end

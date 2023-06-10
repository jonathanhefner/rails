# frozen_string_literal: true

module ActiveSupport
  module Cache
    class SerializerAdapter # :nodoc:
      def initialize(serializer:, compressor:, adapt_dump: true)
        @serializer = serializer
        @compressor = compressor
        @adapt_dump = adapt_dump
        @serializer_dumps_compressed = @serializer.respond_to?(:dump_compressed)
      end

      def dump(entry)
        return serialize(entry) if !@adapt_dump

        dump_compressed(entry, Float::INFINITY)
      end

      def dump_compressed(entry, threshold)
        return serialize(entry, threshold) if !@adapt_dump

        value = entry.value

        # If value is a string with a supported encoding, use it as the payload
        # as is instead of passing it through the serializer.
        if type = type_for_string(value)
          payload = value
        else
          type = OBJECT_DUMP_TYPE
          payload = serialize(Cache::Entry.new(value))
        end

        # Compress payload if it meets the size threshold. (`type < 0` indicates
        # a compressed payload with `type.abs` as its actual type.)
        if compressed = try_compress(payload, threshold)
          payload = compressed
          type = -type
        end

        expires_at = entry.expires_at || -1.0

        version = serialize_version(entry.version)
        version_length = version&.bytesize || -1

        packed = [SIGNATURE, type, expires_at, version_length].pack(PACKED_TEMPLATE)
        packed << version if version
        packed << payload
      end

      def load(dumped)
        return deserialize(dumped) if !dumped?(dumped)

        type = dumped.unpack1(PACKED_TYPE_TEMPLATE)
        expires_at = dumped.unpack1(PACKED_EXPIRES_AT_TEMPLATE)
        version_length = dumped.unpack1(PACKED_VERSION_LENGTH_TEMPLATE)

        expires_at = nil if expires_at < 0
        version = deserialize_version(dumped.byteslice(PACKED_VERSION_INDEX, version_length))
        payload = dumped.byteslice((PACKED_VERSION_INDEX + [version_length, 0].max)..)

        value =
          case type
          when OBJECT_DUMP_TYPE
            -> { deserialize(payload).value }
          when COMPRESSED_OBJECT_DUMP_TYPE
            -> { deserialize(decompress(payload)).value }
          when STRING_DUMP_TYPES
            force_string_encoding(payload, type)
          when COMPRESSED_STRING_DUMP_TYPES
            -> { force_string_encoding(decompress(payload), type) }
          else
            return nil
          end

        Cache::Entry.new(value, version: version, expires_at: expires_at)
      end

      private
        SIGNATURE = "\x00\x11".b.freeze

        OBJECT_DUMP_TYPE = 0x01
        COMPRESSED_OBJECT_DUMP_TYPE = -OBJECT_DUMP_TYPE

        STRING_ENCODINGS = {
          0x02 => Encoding::UTF_8,
          0x03 => Encoding::BINARY,
          0x04 => Encoding::US_ASCII,
        }
        STRING_DUMP_TYPES = STRING_ENCODINGS.keys.to_set
        COMPRESSED_STRING_DUMP_TYPES = STRING_DUMP_TYPES.map(&:-@).to_set

        PACKED_TEMPLATE = "A#{SIGNATURE.bytesize}cEl<"
        PACKED_TYPE_TEMPLATE = "@#{SIGNATURE.bytesize}c"
        PACKED_EXPIRES_AT_TEMPLATE = "@#{[0].pack(PACKED_TYPE_TEMPLATE).bytesize}E"
        PACKED_VERSION_LENGTH_TEMPLATE = "@#{[0].pack(PACKED_EXPIRES_AT_TEMPLATE).bytesize}l<"
        PACKED_VERSION_INDEX = [0].pack(PACKED_VERSION_LENGTH_TEMPLATE).bytesize

        MARSHAL_SIGNATURE = "\x04\x08".b.freeze

        def dumped?(dumped)
          dumped.is_a?(String) && dumped.start_with?(SIGNATURE)
        end

        def serialize(value, compression_threshold = Float::INFINITY)
          if @serializer_dumps_compressed && compression_threshold != Float::INFINITY
            @serializer.dump_compressed(value, compression_threshold)
          else
            @serializer.dump(value)
          end
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

        def type_for_string(value)
          STRING_ENCODINGS.key(value.encoding) if value.instance_of?(String)
        end

        def force_string_encoding(string, type)
          string.force_encoding(STRING_ENCODINGS[type.abs])
        end

        def serialize_version(version)
          if version
            if version.encoding != Encoding::UTF_8 || version.start_with?(MARSHAL_SIGNATURE)
              Marshal.dump(version)
            else
              version
            end
          end
        end

        def deserialize_version(serialized_version)
          if serialized_version
            if serialized_version.start_with?(MARSHAL_SIGNATURE)
              Marshal.load(serialized_version)
            else
              serialized_version.force_encoding(Encoding::UTF_8)
            end
          end
        end
    end
  end
end

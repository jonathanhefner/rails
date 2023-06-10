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
        if !@adapt_dump
          return @serializer.dump(entry)
        end

        dump_compressed(entry, Float::INFINITY)
      end

      def dump_compressed(entry, threshold)
        if !@adapt_dump
          return @serializer_dumps_compressed ? @serializer.dump_compressed(entry, threshold) : @serializer.dump(entry)
        end

        value = entry.value

        if value.instance_of?(String) && type = STRING_ENCODINGS.key(value.encoding)
          payload = value
        else
          type = OBJECT_DUMP_TYPE
          payload = @serializer.dump(Cache::Entry.new(value))
        end

        if payload.bytesize >= threshold
          compressed = @compressor.deflate(payload)
          if compressed.bytesize < payload.bytesize
            type = -type
            payload = compressed
          end
        end

        version = entry.version

        if version && (version.empty? || version.encoding != Encoding::UTF_8)
          version = Marshal.dump(version)
          version_length = -version.bytesize
        else
          version_length = version&.bytesize || 0
        end

        packed = [SIGNATURE, type, entry.expires_at || -1.0, version_length].pack(PACKED_TEMPLATE)
        packed << version if version
        packed << payload
      end

      def load(dumped)
        return @serializer.load(dumped) if !dumped?(dumped)

        type = dumped.unpack1(PACKED_TYPE_TEMPLATE)
        expires_at = dumped.unpack1(PACKED_EXPIRES_AT_TEMPLATE)
        version_length = dumped.unpack1(PACKED_VERSION_LENGTH_TEMPLATE)

        expires_at = nil if expires_at < 0

        if version_length > 0
          version = dumped.byteslice(PACKED_VERSION_INDEX, version_length).force_encoding(Encoding::UTF_8)
        elsif version_length < 0
          version_length = version_length.abs
          version = Marshal.load(dumped.byteslice(PACKED_VERSION_INDEX, version_length))
        end

        payload = dumped.byteslice((PACKED_VERSION_INDEX + version_length)..)

        value =
          case type
          when OBJECT_DUMP_TYPE
            -> { @serializer.load(payload).value }
          when COMPRESSED_OBJECT_DUMP_TYPE
            -> { @serializer.load(@compressor.inflate(payload)).value }
          when STRING_DUMP_TYPES
            payload.force_encoding(STRING_ENCODINGS[type])
          when COMPRESSED_STRING_DUMP_TYPES
            -> { @compressor.inflate(payload).force_encoding(STRING_ENCODINGS[type.abs]) }
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

        def dumped?(dumped)
          dumped.is_a?(String) && dumped.start_with?(SIGNATURE)
        end
    end
  end
end

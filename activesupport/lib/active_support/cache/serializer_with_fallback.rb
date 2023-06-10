# frozen_string_literal: true

require "active_support/core_ext/kernel/reporting"

module ActiveSupport
  module Cache
    module SerializerWithFallback # :nodoc:
      def self.[](format)
        if format.to_s.include?("message_pack") && !defined?(ActiveSupport::MessagePack)
          require "active_support/message_pack"
        end

        SERIALIZERS.fetch(format)
      end

      def dump(entry)
        try_dump_bare_string(entry) || _dump(entry)
      end

      def load(dumped)
        if dumped.is_a?(String)
          case
          when loaded = try_load_bare_string(dumped)
            loaded
          when MessagePackWithFallback.dumped?(dumped)
            MessagePackWithFallback._load(dumped)
          when Marshal71WithFallback.dumped?(dumped)
            Marshal71WithFallback._load(dumped)
          when Marshal61WithFallback.dumped?(dumped)
            Marshal61WithFallback._load(dumped)
          else
            Cache::Store.logger&.warn("Unrecognized payload prefix #{dumped.byteslice(0).inspect}; deserializing as nil")
            nil
          end
        elsif PassthroughWithFallback.dumped?(dumped)
          PassthroughWithFallback._load(dumped)
        else
          Cache::Store.logger&.warn("Unrecognized payload class #{dumped.class}; deserializing as nil")
          nil
        end
      end

      private
        BARE_STRING_SIGNATURES = {
          255 => Encoding::UTF_8,
          254 => Encoding::BINARY,
          253 => Encoding::US_ASCII,
        }
        BARE_STRING_TEMPLATE = "CEl<"
        BARE_STRING_EXPIRES_AT_TEMPLATE = "@1E"
        BARE_STRING_VERSION_LENGTH_TEMPLATE = "@#{[0].pack(BARE_STRING_EXPIRES_AT_TEMPLATE).bytesize}l<"
        BARE_STRING_VERSION_INDEX = [0].pack(BARE_STRING_VERSION_LENGTH_TEMPLATE).bytesize

        def try_dump_bare_string(entry)
          value = entry.value
          return if !value.instance_of?(String)

          version = entry.version
          return if version && version.encoding != Encoding::UTF_8

          signature = BARE_STRING_SIGNATURES.key(value.encoding)
          return if !signature

          packed = [signature, entry.expires_at || -1.0, version&.bytesize || -1].pack(BARE_STRING_TEMPLATE)
          packed << version if version
          packed << value
        end

        def try_load_bare_string(dumped)
          encoding = BARE_STRING_SIGNATURES[dumped.getbyte(0)]
          return if !encoding
          expires_at = dumped.unpack1(BARE_STRING_EXPIRES_AT_TEMPLATE)
          version_length = dumped.unpack1(BARE_STRING_VERSION_LENGTH_TEMPLATE)
          value_index = BARE_STRING_VERSION_INDEX + [version_length, 0].max

          Cache::Entry.new(
            dumped.byteslice(value_index..-1).force_encoding(encoding),
            version: dumped.byteslice(BARE_STRING_VERSION_INDEX, version_length)&.force_encoding(Encoding::UTF_8),
            expires_at: (expires_at unless expires_at < 0),
          )
        end

        module PassthroughWithFallback
          include SerializerWithFallback
          extend self

          def dump(entry)
            entry
          end

          def dump_compressed(entry, threshold)
            entry.compressed(threshold)
          end

          def _load(entry)
            entry
          end

          def dumped?(dumped)
            dumped.is_a?(Cache::Entry)
          end
        end

        module Marshal61WithFallback
          include SerializerWithFallback
          extend self

          SIGNATURE = "\x04\x08o".b.freeze

          def dump(entry)
            Marshal.dump(entry)
          end

          def dump_compressed(entry, threshold)
            Marshal.dump(entry.compressed(threshold))
          end

          def _load(dumped)
            Marshal.load(dumped)
          end

          def dumped?(dumped)
            dumped.start_with?(SIGNATURE)
          end
        end

        module Marshal71WithFallback
          include SerializerWithFallback
          extend self

          SIGNATURE = "\x04\x08[".b.freeze

          def _dump(entry)
            Marshal.dump(entry.pack)
          end

          def _load(dumped)
            Cache::Entry.unpack(Marshal.load(dumped))
          end

          def dumped?(dumped)
            dumped.start_with?(SIGNATURE)
          end
        end

        module Marshal70WithFallback
          include Marshal71WithFallback
          extend self
          alias :dump :_dump # Prevent dumping bare strings.
        end

        module MessagePackWithFallback
          include SerializerWithFallback
          extend self

          def _dump(entry)
            ActiveSupport::MessagePack::CacheSerializer.dump(entry.pack)
          end

          def _load(dumped)
            packed = ActiveSupport::MessagePack::CacheSerializer.load(dumped)
            Cache::Entry.unpack(packed) if packed
          end

          def dumped?(dumped)
            available? && ActiveSupport::MessagePack.signature?(dumped)
          end

          private
            def available?
              return @available if defined?(@available)
              silence_warnings { require "active_support/message_pack" }
              @available = true
            rescue LoadError
              @available = false
            end
        end

        SERIALIZERS = {
          passthrough: PassthroughWithFallback,
          marshal_6_1: Marshal61WithFallback,
          marshal_7_0: Marshal70WithFallback,
          marshal_7_1: Marshal71WithFallback,
          message_pack: MessagePackWithFallback,
        }
    end
  end
end

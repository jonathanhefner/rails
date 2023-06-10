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

      def load(dumped)
        if dumped.is_a?(String)
          case
          when MessagePackWithFallback.dumped?(dumped)
            MessagePackWithFallback._load(dumped)
          when Marshal71WithFallback.dumped?(dumped)
            Marshal71WithFallback._load(dumped)
          when Marshal70WithFallback.dumped?(dumped)
            Marshal70WithFallback._load(dumped)
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
        module PassthroughWithFallback
          include SerializerWithFallback
          extend self

          def dump_as_entry(entry)
            entry
          end
          alias :dump :dump_as_entry

          def dump_compressed_as_entry(entry, threshold)
            entry.compressed(threshold)
          end
          alias :dump_compressed :dump_compressed_as_entry

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

          MARSHAL_SIGNATURE = "\x04\x08o".b.freeze

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
            dumped.start_with?(MARSHAL_SIGNATURE)
          end
        end

        module Marshal70WithFallback
          include SerializerWithFallback
          extend self

          MARK_UNCOMPRESSED = "\x00".b.freeze
          MARK_COMPRESSED   = "\x01".b.freeze

          def dump(entry)
            MARK_UNCOMPRESSED + Marshal.dump(entry.pack)
          end

          def dump_compressed(entry, threshold)
            dumped = Marshal.dump(entry.pack)

            if dumped.bytesize >= threshold
              compressed = Zlib::Deflate.deflate(dumped)
              return MARK_COMPRESSED + compressed if compressed.bytesize < dumped.bytesize
            end

            MARK_UNCOMPRESSED + dumped
          end

          def _load(marked)
            dumped = marked.byteslice(1..-1)
            dumped = Zlib::Inflate.inflate(dumped) if marked.start_with?(MARK_COMPRESSED)
            Cache::Entry.unpack(Marshal.load(dumped))
          end

          def dumped?(dumped)
            dumped.start_with?(MARK_UNCOMPRESSED, MARK_COMPRESSED)
          end
        end

        module Marshal71WithFallback
          include SerializerWithFallback
          extend self

          MARSHAL_SIGNATURE = "\x04\x08[".b.freeze

          def dump(entry)
            Marshal.dump(entry.pack)
          end

          def _load(dumped)
            Cache::Entry.unpack(Marshal.load(dumped))
          end

          def dumped?(dumped)
            dumped.start_with?(MARSHAL_SIGNATURE)
          end
        end

        module MessagePackWithFallback
          include SerializerWithFallback
          extend self

          def dump(entry)
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

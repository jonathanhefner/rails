# frozen_string_literal: true

require_relative "serializer"

module ActiveSupport
  module MessagePack
    module CacheSerializer
      extend Serializer
      extend self

      def dump(entry)
        super(entry.pack)
      end

      def dump_compressed(entry, threshold) # :nodoc:
        dumped = dump(entry)
        dumped = Zlib::Deflate.deflate(dumped) if dumped.bytesize >= threshold
        dumped
      end

      def load(dumped)
        dumped = Zlib::Inflate.inflate(dumped) if !signature?(dumped)
        ActiveSupport::Cache::Entry.unpack(super)
      rescue ActiveSupport::MessagePack::MissingClassError
        # Treat missing class as cache miss => return nil
      end
    end
  end
end

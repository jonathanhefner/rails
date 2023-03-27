# frozen_string_literal: true

module ActiveSupport
  module MessagePack
    module Serializer # :nodoc:
      SIGNATURE = (+"\xCC\x80").force_encoding("ASCII-8BIT").freeze # == 128.to_msgpack
      SIGNATURE_INT = 128

      attr_accessor :message_pack_factory

      def dump(object)
        message_pack_pool.packer do |packer|
          packer.write(SIGNATURE_INT)
          packer.write(object)
          packer.full_pack
        end
      end

      def load(dumped)
        message_pack_pool.unpacker do |unpacker|
          unpacker.feed_reference(dumped)
          raise "Invalid serialization format" unless unpacker.read == SIGNATURE_INT
          unpacker.full_unpack
        end
      end

      def signature?(message)
        message.start_with?(SIGNATURE)
      end

      def register_type(id, ...)
        raise "Type ID #{id} has already been registered" if message_pack_factory.type_registered?(id)
        message_pack_factory.register_type(id, ...)
      end

      private
        def message_pack_pool
          @message_pack_pool ||= message_pack_factory.pool(ENV.fetch("RAILS_MAX_THREADS") { 5 })
        end
    end
  end
end

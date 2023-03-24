# frozen_string_literal: true

module ActiveSupport
  module MessagePack
    module Serializer # :nodoc:
      attr_accessor :message_pack_factory

      def dump(object)
        @packer_key ||= "message_pack_packer_#{object_id}"
        packer = (IsolatedExecutionState[@packer_key] ||= message_pack_factory.packer)

        # TODO RFC:
        # Write `true` ("\xC3") and `false` ("\xC2") as a kind of signature.
        # Consuming code can check `start_with?("\xC3\xC2")` to determine
        # whether the payload was serialized with MessagePack, similar to
        # checking `start_with?("\x04\x08")` for Marshal.
        packer.write(true)
        packer.write(false)

        packer.write(object)
        packer.full_pack
      ensure
        packer.reset
      end

      def load(serialized)
        @unpacker_key ||= "message_pack_unpacker_#{object_id}"
        unpacker = (IsolatedExecutionState[@unpacker_key] ||= message_pack_factory.unpacker)

        unpacker.feed(serialized)

        unless unpacker.read == true && unpacker.read == false
          raise "Invalid serialization format"
        end

        unpacker.full_unpack
      ensure
        unpacker.reset
      end

      def register_type(id, ...)
        raise "Type ID #{id} has already been registered" if message_pack_factory.type_registered?(id)
        message_pack_factory.register_type(id, ...)
      end
    end
  end
end

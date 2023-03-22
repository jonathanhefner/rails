# frozen_string_literal: true

gem "msgpack", ">= 1.7.0"
require "msgpack"
require_relative "message_pack/cache_serializer"
require_relative "message_pack/serializer"

module ActiveSupport
  module MessagePack
    extend Serializer

    ##
    # :singleton-method: dump
    # :call-seq: dump(object)
    #
    # Dumps an object. Raises ActiveSupport::MessagePack::UnserializableObjectError
    # if the object type is not supported.
    #
    #--
    # Implemented by Serializer#dump.

    ##
    # :singleton-method: load
    # :call-seq: load(dumped)
    #
    # Loads an object dump created by ::dump.
    #
    #--
    # Implemented by Serializer#load.

    ##
    # :singleton-method: signature?
    # :call-seq: signature?(dumped)
    #
    # Returns true if the given dump begins with an +ActiveSupport::MessagePack+
    # signature.
    #
    #--
    # Implemented by Serializer#signature?.

    ActiveSupport.run_load_hooks(:message_pack, self)
  end
end

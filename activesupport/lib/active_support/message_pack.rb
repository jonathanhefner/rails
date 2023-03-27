# frozen_string_literal: true

gem "msgpack", ">= 1.7.0"
require "msgpack"
require_relative "message_pack/cache_serializer"
require_relative "message_pack/extensions"
require_relative "message_pack/serializer"

module ActiveSupport
  module MessagePack
    extend Serializer

    self.message_pack_factory = ::MessagePack::Factory.new
    Extensions.install(message_pack_factory)
    CacheSerializer.message_pack_factory = message_pack_factory.dup
    # FIXME This shouldn't be necessary, but the `oversized_integer_extension`
    # option is not properly dup'ed, so re-install.
    Extensions.install(CacheSerializer.message_pack_factory)

    ActiveSupport.run_load_hooks(:message_pack, self)

    Extensions.install_unregistered_type_error_handler(message_pack_factory)
    Extensions.install_unregistered_type_fallback(CacheSerializer.message_pack_factory)

    message_pack_factory.freeze
    CacheSerializer.message_pack_factory.freeze
  end
end

# frozen_string_literal: true

begin
  require "msgpack"
  require "msgpack/bigint"
rescue LoadError => error
  # TODO
end

require_relative "message_pack/extensions"
require_relative "message_pack/serializer"

module ActiveSupport
  module MessagePack
    extend Serializer
    self.message_pack_factory = Extensions.configure_factory(::MessagePack::Factory.new)

    module CacheSerializer
      extend Serializer
      self.message_pack_factory = ActiveSupport::MessagePack.message_pack_factory.dup
      # .tap do |factory|
      #   factory.register_type 126, ActiveRecord::Base,
      #     packer: :marshal_dump,
      #     unpacker: :marshal_load
      # end
    end
  end
end

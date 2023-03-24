# frozen_string_literal: true

begin
  require "msgpack"
rescue LoadError => error
  $stderr.puts "You don't have msgpack installed in your application. " \
    "Please add it to your Gemfile and run bundle install."
  raise error
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
    end

    ActiveSupport.run_load_hooks(:message_pack, self)
  end
end

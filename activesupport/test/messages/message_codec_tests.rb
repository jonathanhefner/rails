# frozen_string_literal: true

require "active_support/core_ext/object/with"

module MessageCodecTests
  extend ActiveSupport::Concern

  included do
    test "Codec::default_serializer determines the default serializer" do
      ActiveSupport::Messages::Codec.with(default_serializer: ::Marshal) do
        assert_serializer ::Marshal, make_codec
      end

      ActiveSupport::Messages::Codec.with(default_serializer: ::JSON) do
        assert_serializer ::JSON, make_codec
      end
    end

    test ":serializer option resolves symbols as SerializerWithFallback serializers" do
      serializers = {
        marshal: ActiveSupport::SerializerWithFallback::MarshalWithFallback,
        json: ActiveSupport::SerializerWithFallback::JsonWithFallback,
        message_pack: ActiveSupport::SerializerWithFallback::MessagePackWithFallback,
      }

      serializers.each do |symbol, serializer|
        assert_serializer serializer, make_codec(serializer: symbol)
      end
    end

    test ":serializer option raises when given invalid symbol" do
      assert_raises(match: /TODO/) do
        make_codec(serializer: :invalid_name)
      end
    end
  end

  private
    def assert_serializer(serializer, codec)
      assert_equal serializer, codec.send(:serializer)
    end
end

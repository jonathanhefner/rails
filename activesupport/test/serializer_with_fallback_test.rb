# frozen_string_literal: true

require_relative "abstract_unit"
require "json"
require "active_support/core_ext/object/with"

class SerializerWithFallbackTest < ActiveSupport::TestCase
  test ":marshal serializer dumps objects using Marshal format" do
    assert_roundtrip serializer(:marshal), ::Marshal
  end

  test ":json serializer dumps objects using JSON format" do
    assert_roundtrip serializer(:json), ::JSON
  end

  test ":message_pack serializer dumps objects using MessagePack format" do
    assert_roundtrip serializer(:message_pack), ActiveSupport::MessagePack
  end

  test "every serializer can load every format when ::marshal_fallback is true" do
    ActiveSupport::SerializerWithFallback.with(marshal_fallback: true) do
      FORMATS.product(FORMATS) do |dumping, loading|
        assert_roundtrip serializer(dumping), serializer(loading)
      end
    end
  end

  test "every serializer can load every non-Marshal format when ::marshal_fallback is false" do
    ActiveSupport::SerializerWithFallback.with(marshal_fallback: false) do
      (FORMATS - [:marshal]).product(FORMATS) do |dumping, loading|
        assert_roundtrip serializer(dumping), serializer(loading)
      end
    end
  end

  test "only :marshal serializer can load Marshal format when ::marshal_fallback is false" do
    ActiveSupport::SerializerWithFallback.with(marshal_fallback: false) do
      assert_roundtrip serializer(:marshal), serializer(:marshal)

      marshalled = serializer(:marshal).dump({})
      (FORMATS - [:marshal]).each do |loading|
        assert_raises(match: /TODO/) do
          serializer(loading).load(marshalled)
        end
      end
    end
  end

  test "logs when falling back to Marshal format" do
  end

  test "raises on invalid format name" do
  end

  private
    FORMATS = [:marshal, :json, :message_pack]

    def serializer(format)
      ActiveSupport::SerializerWithFallback[format]
    end

    def assert_roundtrip(serializer, deserializer = serializer)
      value = [{ "a_boolean" => false, "a_number" => 123 }]
      assert_equal value, deserializer.load(serializer.dump(value))
    end
end

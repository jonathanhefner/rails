# frozen_string_literal: true

require_relative "abstract_unit"
require "json"

class SerializerWithFallbackTest < ActiveSupport::TestCase
  test ":marshal serializer dumps objects using Marshal format" do
    assert_roundtrip serializer(:marshal), ::Marshal
  end

  test ":json serializer dumps objects using JSON format" do
    assert_roundtrip serializer(:json), ::JSON
    assert_roundtrip serializer(:json_allow_marshal), ::JSON
  end

  test ":message_pack serializer dumps objects using MessagePack format" do
    assert_roundtrip serializer(:message_pack), ActiveSupport::MessagePack
    assert_roundtrip serializer(:message_pack_allow_marshal), ActiveSupport::MessagePack
  end

  test "every serializer can load every non-Marshal format" do
    (FORMATS - [:marshal]).product(FORMATS) do |dumping, loading|
      assert_roundtrip serializer(dumping), serializer(loading)
    end
  end

  test "only :marshal and :*_allow_marshal serializers can load Marshal format" do
    marshal_loading_formats = FORMATS.grep(/(?:\A|_allow_)marshal/)

    marshal_loading_formats.each do |loading|
      assert_roundtrip serializer(:marshal), serializer(loading)
    end

    marshalled = serializer(:marshal).dump({})

    (FORMATS - marshal_loading_formats).each do |loading|
      assert_raises(match: /TODO/) do
        serializer(loading).load(marshalled)
      end
    end
  end

  test "notifies when serializer falls back to loading Marshal format" do
    value = ["foo"]
    dumped = serializer(:marshal).dump(value)
    notifying_formats = FORMATS.grep(/_allow_marshal/)
    assert_not_empty notifying_formats

    payloads = []
    callback = -> (*args) { payloads << args.extract_options! }
    ActiveSupport::Notifications.subscribed(callback, "message_serializer_fallback.active_support") do
      notifying_formats.each do |notifying|
        serializer(notifying).load(dumped)
      end
    end

    assert_equal notifying_formats, payloads.map { |payload| payload[:serializer] }
    payloads.each do |payload|
      assert_equal :marshal, payload[:fallback]
      assert_equal dumped, payload[:message]
      assert_equal value, payload[:value]
    end
  end

  test "raises on invalid format name" do
    assert_raises KeyError do
      ActiveSupport::SerializerWithFallback[:invalid_format]
    end
  end

  private
    FORMATS = ActiveSupport::SerializerWithFallback::SERIALIZERS.keys

    def serializer(format)
      ActiveSupport::SerializerWithFallback[format]
    end

    def assert_roundtrip(serializer, deserializer = serializer)
      value = [{ "a_boolean" => false, "a_number" => 123 }]
      assert_equal value, deserializer.load(serializer.dump(value))
    end
end

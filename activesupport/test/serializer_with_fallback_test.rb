# frozen_string_literal: true

require_relative "abstract_unit"
require "json"
require "stringio"

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

  test "logs when serializer falls back to loading Marshal format" do
    FORMATS.grep(/_allow_marshal/) do |loading|
      out = StringIO.new
      with_rails_logger(Logger.new(out)) do
        assert_roundtrip serializer(:marshal), serializer(loading)
        assert_match "TODO", out.string
      end
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

    module ::Rails; end # Ensure existence for stubbing.

    def with_rails_logger(logger)
      stub = Module.new { define_singleton_method(:logger) { logger } }
      stub_const Object, :Rails, stub do
        yield logger
      end
    end
end

# frozen_string_literal: true

require_relative "abstract_unit"

class SerializerWithFallbackTest < ActiveSupport::TestCase
  test ":marshal serializer dumps objects using Marshal format" do
    assert_roundtrip ActiveSupport::SerializerWithFallback[:marshal], ::Marshal
  end

  test ":json serializer dumps objects using JSON format" do
    assert_roundtrip ActiveSupport::SerializerWithFallback[:json], ::JSON
  end

  test ":message_pack serializer dumps objects using MessagePack format" do
    assert_roundtrip ActiveSupport::SerializerWithFallback[:message_pack], ActiveSupport::MessagePack
  end

  test "every serializer can load every format" do
    serializers.product(serializers) do |dumper, loader|
      assert_roundtrip dumper, loader
    end
  end

  private
    def serializers
      @serializers ||= [:marshal, :json, :message_pack].map do |format|
        ActiveSupport::SerializerWithFallback[format]
      end
    end

    def assert_roundtrip(dumper, loader = dumper)
      value = [{ "a_boolean" => false, "a_number" => 123 }]
      assert_equal value, loader.load(dumper.dump(value))
    end
end

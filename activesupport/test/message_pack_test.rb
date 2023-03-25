# frozen_string_literal: true

require_relative "abstract_unit"

class MessagePackTest < ActiveSupport::TestCase
  setup do
    ActiveSupport::MessagePack # trigger load of all types for roundtripping
  end

  test "enshrines type IDs" do
    expected = {
      0   => Symbol,
      1   => Integer,
      2   => BigDecimal,
      3   => Rational,
      4   => Complex,
      5   => Range,
      6   => ActiveSupport::HashWithIndifferentAccess,
      7   => Set,
      8   => Time,
      9   => DateTime,
      10  => Date,
      11  => ActiveSupport::TimeWithZone,
      12  => ActiveSupport::TimeZone,
      13  => ActiveSupport::Duration,
      14  => URI::Generic,
      15  => IPAddr,
      16  => Pathname,
      17  => Regexp,
      18  => Module,
      127 => Object,
    }

    actual = ActiveSupport::MessagePack.message_pack_factory.registered_types.to_h do |entry|
      [entry[:type], entry[:class]]
    end

    assert_equal expected, actual
  end

  test "roundtrips Symbol" do
    assert_roundtrip :some_symbol
  end

  test "roundtrips very large Integer" do
    assert_roundtrip 2**512
  end

  test "roundtrips BigDecimal" do
    assert_roundtrip BigDecimal("9876543210.0123456789")
  end

  test "roundtrips Rational" do
    assert_roundtrip Rational(1, 3)
  end

  test "optimizes Rational zero encoding" do
    assert_roundtrip Rational(0, 1)

    serialized_zero = ActiveSupport::MessagePack.dump(Rational(0, 1))
    serialized_nonzero = ActiveSupport::MessagePack.dump(Rational(1, 1))
    assert_operator serialized_zero.size, :<, serialized_nonzero.size
  end

  test "roundtrips Complex" do
    assert_roundtrip Complex(1, -1)
  end

  test "roundtrips Range" do
    assert_roundtrip 1..2
    assert_roundtrip 1...2
    assert_roundtrip 1..nil
    assert_roundtrip 1...nil
    assert_roundtrip nil..2
    assert_roundtrip nil...2
    assert_roundtrip "1".."2"
    assert_roundtrip "1"..."2"
  end

  test "roundtrips ActiveSupport::HashWithIndifferentAccess" do
    assert_roundtrip ActiveSupport::HashWithIndifferentAccess.new(a: true, b: 2, c: "three")
  end

  test "roundtrips Set" do
    assert_roundtrip Set.new([nil, true, 2, "three"])
  end

  test "roundtrips Time" do
    assert_roundtrip Time.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), "-12:00")
    assert_roundtrip Time.now
  end

  test "roundtrips DateTime" do
    assert_roundtrip DateTime.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), Rational(-1, 2))
    assert_roundtrip DateTime.now
  end

  test "roundtrips Date" do
    assert_roundtrip Date.new(1999, 12, 31)
    assert_roundtrip Date.today
  end

  test "roundtrips ActiveSupport::TimeWithZone" do
    assert_roundtrip ActiveSupport::TimeWithZone.new(
      Time.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), "UTC"),
      ActiveSupport::TimeZone["Australia/Lord_Howe"]
    )
    assert_roundtrip Time.current
  end

  test "roundtrips ActiveSupport::TimeZone" do
    assert_roundtrip ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  test "roundtrips ActiveSupport::Duration" do
    assert_roundtrip 1.year + 2.months + 3.weeks + 4.days + 5.hours + 6.minutes + 7.seconds
    assert_roundtrip 1.month + 1.day
  end

  test "roundtrips URI::Generic" do
    assert_roundtrip URI("https://example.com/#test")
  end

  test "roundtrips IPAddr" do
    assert_roundtrip IPAddr.new("127.0.0.1")
  end

  test "roundtrips Pathname" do
    assert_roundtrip Pathname(__FILE__)
  end

  test "roundtrips Regexp" do
    assert_roundtrip %r/(?m-ix:.*)/
  end

  test "roundtrips Module" do
    assert_roundtrip ActiveSupport::MessagePack
  end

  test "raises error when serializing anonymous Module" do
    assert_raises(match: /anonymous/i) do
      ActiveSupport::MessagePack.dump(Module.new)
    end
  end

  class DefinesAsJson
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      self.class == other.class && value == other.value
    end

    def as_json
      { "as_json" => value }
    end
  end

  class DefinesSerializableHash < DefinesAsJson
    def serializable_hash
      { "serializable_hash" => value }
    end
  end

  class DefinesJsonCreate < DefinesSerializableHash
    def self.json_create(hash)
      DefinesJsonCreate.new(hash["as_json"])
    end
  end

  class DefinesFromMsgpackExt < DefinesJsonCreate
    def self.from_msgpack_ext(string)
      DefinesFromMsgpackExt.new(string.chomp!("msgpack_ext"))
    end

    def to_msgpack_ext
      value + "msgpack_ext"
    end
  end

  class Unserializable < DefinesAsJson
    undef_method :as_json
  end

  test "uses #to_msgpack_ext and ::from_msgpack_ext to roundtrip unregistered objects" do
    assert_roundtrip DefinesFromMsgpackExt.new("foo")
  end

  test "uses #as_json and ::json_create to roundtrip unregistered objects" do
    assert_roundtrip DefinesJsonCreate.new("foo")
  end

  test "uses #serializable_hash to serialize unregistered objects" do
    serialized = ActiveSupport::MessagePack.dump(DefinesSerializableHash.new("foo"))
    deserialized = ActiveSupport::MessagePack.load(serialized)
    assert_equal({ "serializable_hash" => "foo" }, deserialized)
  end

  test "uses #as_json to serialize unregistered objects" do
    serialized = ActiveSupport::MessagePack.dump(DefinesAsJson.new("foo"))
    deserialized = ActiveSupport::MessagePack.load(serialized)
    assert_equal({ "as_json" => "foo" }, deserialized)
  end

  test "raises error when unable to serialize an unregistered object" do
    assert_raises(match: /unrecognized type/i) do
      ActiveSupport::MessagePack.dump(Unserializable.new("foo"))
    end
  end

  private
    def assert_roundtrip(object)
      serialized = ActiveSupport::MessagePack.dump(object)
      assert_kind_of String, serialized

      deserialized = ActiveSupport::MessagePack.load(serialized)
      assert_instance_of object.class, deserialized
      assert_equal object, deserialized
    end
end

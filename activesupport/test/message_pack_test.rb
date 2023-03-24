# frozen_string_literal: true

require_relative "abstract_unit"

class MessagePackTest < ActiveSupport::TestCase
  setup do
    ActiveSupport::MessagePack # trigger load of all types for roundtripping
  end

  test "roundtrips Object" do
    # TODO
  end

  test "roundtrips Symbol" do
    assert_roundtrip :some_symbol
  end

  test "roundtrips Module" do
    assert_roundtrip ActiveSupport::MessagePack
  end

  test "raises error when dumping anonymous Module" do
    assert_raises do
      ActiveSupport::MessagePack.dump(Module.new)
    end
  end

  test "roundtrips very large Integer" do
    assert_roundtrip 2**512
  end

  test "roundtrips BigDecimal" do
    assert_roundtrip BigDecimal("9876543210.01234556789")
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

  test "roundtrips Set" do
    assert_roundtrip Set.new([nil, true, 2, "three"])
  end

  test "roundtrips Regexp" do
    assert_roundtrip %r/(?m-ix:.*)/
  end

  test "roundtrips Pathname" do
    assert_roundtrip Pathname(__FILE__)
  end

  test "roundtrips URI::Generic" do
    assert_roundtrip URI("https://example.com/#test")
  end

  test "roundtrips IPAddr" do
    assert_roundtrip IPAddr.new("127.0.0.1")
  end

  test "roundtrips Date" do
    assert_roundtrip Date.new(1999, 12, 31)
    assert_roundtrip Date.today
  end

  test "roundtrips DateTime" do
    assert_roundtrip DateTime.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), Rational(-1, 2))
    assert_roundtrip DateTime.now
  end

  test "roundtrips Time" do
    assert_roundtrip Time.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), "-12:00")
    assert_roundtrip Time.now
  end

  test "roundtrips ActiveSupport::TimeWithZone" do
    assert_roundtrip ActiveSupport::TimeWithZone.new(
      Time.new(1999, 12, 31, 12, 34, 56 + Rational(789, 1000), "-12:00").utc,
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

  test "roundtrips ActiveSupport::HashWithIndifferentAccess" do
    assert_roundtrip ActiveSupport::HashWithIndifferentAccess.new(a: true, b: 2, c: "three")
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

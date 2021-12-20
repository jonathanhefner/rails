# frozen_string_literal: true

require "cases/helper"
require "models/aircraft"
require "active_support/core_ext/string/inflections"

class NormalizedAttributeTest < ActiveRecord::TestCase
  class NormalizedAircraft < Aircraft
    normalizes :name, with: -> name { name.titlecase }
    normalizes :manufactured_at, with: -> time { time.noon }

    attr_accessor :validated_name
    validate do
      self.validated_name = name
    end
  end

  setup do
    @now = Time.current.utc
    @aircraft = NormalizedAircraft.create!(name: "fly HIGH", manufactured_at: @now)
  end

  test "normalizes value from create" do
    assert_equal "Fly High", @aircraft.name
  end

  test "normalizes value from update" do
    @aircraft.update!(name: "fly HIGHER")
    assert_equal "Fly Higher", @aircraft.name
  end

  test "normalizes value from assignment" do
    @aircraft.name = "fly HIGHER"
    assert_equal "Fly Higher", @aircraft.name
  end

  test "normalizes changed-in-place value before validation" do
    @aircraft.name.downcase!
    assert_equal "fly high", @aircraft.name

    @aircraft.valid?
    assert_equal "Fly High", @aircraft.validated_name
  end

  test "normalizes value on demand" do
    @aircraft.name.downcase!
    assert_equal "fly high", @aircraft.name

    @aircraft.normalize_attribute(:name)
    assert_equal "Fly High", @aircraft.name
  end

  test "normalizes value without record" do
    assert_equal "Titlecase Me", NormalizedAircraft.normalize(:name, "titlecase ME")
  end

  test "casts value before applying normalization" do
    @aircraft.manufactured_at = (@now.noon + 1.minute).to_s
    assert_equal @now.noon, @aircraft.manufactured_at
  end

  test "can specify normalization as an object that responds to to_proc" do
    with_symbol = Class.new(Aircraft) do
      normalizes :name, with: :titlecase
    end

    assert_equal "Titlecase Me", with_symbol.normalize(:name, "titlecase ME")
  end

  test "can specify normalization as multiple objects that respond to to_proc" do
    with_array = Class.new(Aircraft) do
      normalizes :name, with: [:titlecase, :reverse]
    end

    assert_equal "eM esreveR nehT esaceltiT", with_array.normalize(:name, "titlecase THEN reverse ME")
  end

  test "ignores nil by default" do
    assert_nil NormalizedAircraft.normalize(:name, nil)
  end

  test "normalizes nil if including_nil_values" do
    including_nil = Class.new(Aircraft) do
      normalizes :name, including_nil_values: true, with: -> name { name&.titlecase || "Untitled" }
    end

    assert_equal "Untitled", including_nil.normalize(:name, nil)
  end

  test "does not automatically normalize value from database" do
    from_database = NormalizedAircraft.find(Aircraft.create(name: "NOT titlecase").id)
    assert_equal "NOT titlecase", from_database.name
  end

  test "finds record by normalized value" do
    assert_equal @now.noon, @aircraft.manufactured_at
    assert_equal @aircraft, NormalizedAircraft.find_by(manufactured_at: (@now.noon + 1.minute).to_s)
  end

  test "can stack normalizations" do
    titlecase_then_reverse = Class.new(NormalizedAircraft) do
      normalizes :name, with: -> name { name.reverse }
    end

    assert_equal "eM esreveR nehT esaceltiT", titlecase_then_reverse.normalize(:name, "titlecase THEN reverse ME")
    assert_equal "Only Titlecase Me", NormalizedAircraft.normalize(:name, "ONLY titlecase ME")
  end

  test "minimizes number of times normalization is applied" do
    count_applied = Class.new(Aircraft) do
      normalizes :name, with: -> name { name.succ }
    end

    aircraft = count_applied.create!(name: "0")
    assert_equal "1", aircraft.name

    aircraft.name = "0"
    assert_equal "1", aircraft.name
    aircraft.save
    assert_equal "1", aircraft.name

    aircraft.name.replace("0")
    assert_equal "0", aircraft.name
    aircraft.save
    assert_equal "1", aircraft.name
  end
end

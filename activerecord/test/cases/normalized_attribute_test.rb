# frozen_string_literal: true

require "cases/helper"
require "models/aircraft"

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

  test "passes cast value to normalizer" do
    @aircraft.manufactured_at = (@now.noon + 1.minute).to_s
    assert_equal @now.noon, @aircraft.manufactured_at
  end

  test "can specify normalizer as symbol" do
    with_symbol_normalizer = Class.new(Aircraft) do
      normalizes :name, with: :titlecase
    end

    assert_equal "Titlecase Me", with_symbol_normalizer.normalize(:name, "titlecase ME")
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
    titlecase_and_squish = Class.new(NormalizedAircraft) do
      normalizes :name, with: -> name { name.squish }
    end

    assert_equal "Titlecase And Squish Me", titlecase_and_squish.normalize(:name, "titlecase  AND  squish ME\n")
    assert_equal "Only  Titlecase  Me\n", NormalizedAircraft.normalize(:name, "ONLY  titlecase  ME\n")
  end

  test "minimizes number of normalizer calls" do
    counting_normalizes = Class.new(Aircraft) do
      normalizes :name, with: -> name { name.succ }
    end

    aircraft = counting_normalizes.create!(name: "0")
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

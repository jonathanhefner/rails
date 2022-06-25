# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/module/singleton_attribute"

class ModuleSingletonAttributeTest < ActiveSupport::TestCase
  setup do
    @module = Module.new { singleton_attribute :foo }
    @class = Class.new { singleton_attribute :foo }
  end

  test "works with module" do
    @module.foo = :value
    assert_equal :value, @module.foo
  end

  test "works with class" do
    @class.foo = :value
    assert_equal :value, @class.foo
  end

  test "supports multiple attribute names" do
    @module.singleton_attribute :bar, :baz
    @module.baz = :value
    assert_equal :value, @module.baz
  end

  test "supports default value" do
    @module.singleton_attribute :bar, default: :default_value
    assert_equal :default_value, @module.bar
  end

  test "can be read via subclass" do
    subclass = Class.new(@class)
    @class.foo = :value
    assert_equal :value, subclass.foo
  end

  test "can be written via subclass" do
    subclass = Class.new(@class)
    subclass.foo = :value
    assert_equal :value, @class.foo
  end

  test "can be overridden by subclass" do
    subclass = Class.new(@class) { singleton_attribute :foo }
    @class.foo = :class_value
    subclass.foo = :subclass_value

    assert_equal :class_value, @class.foo
    assert_equal :subclass_value, subclass.foo
  end
end

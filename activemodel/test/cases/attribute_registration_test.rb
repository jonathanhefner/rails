# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  class AttributeRegistrationTest < ActiveModel::TestCase
    MyType = Class.new(Type::Value)
    MyDecorator = DelegateClass(Type::Value) { alias subtype __getobj__ }
    MyOtherDecorator = MyDecorator.dup

    Type.register(MyType.name.to_sym, MyType)
    TYPE_1 = MyType.new(precision: 1)
    TYPE_2 = MyType.new(precision: 2)

    test "attributes can be registered" do
      attributes = default_attributes_for { attribute :foo, TYPE_1 }
      assert_same TYPE_1, attributes["foo"].type
    end

    test "the default type is used when type is omitted" do
      attributes = default_attributes_for { attribute :foo }
      assert_equal Type::Value.new, attributes["foo"].type
    end

    test "type is resolved when specified by name" do
      attributes = default_attributes_for { attribute :foo, MyType.name.to_sym }
      assert_instance_of MyType, attributes["foo"].type
    end

    test "type options are forwarded when type is specified by name" do
      attributes = default_attributes_for { attribute :foo, MyType.name.to_sym, precision: 123 }
      assert_equal 123, attributes["foo"].type.precision
    end

    test "default value can be specified" do
      attributes = default_attributes_for { attribute :foo, default: 321 }
      assert_equal 321, attributes["foo"].value
    end

    test "default value can be nil" do
      attributes = default_attributes_for do
        attribute :foo, default: nil
        attribute :bar
      end

      assert_predicate attributes["foo"], :came_from_user?
      assert_not_predicate attributes["bar"], :came_from_user?
    end

    test "types can be decorated" do
      attributes = default_attributes_for do
        attribute :foo, TYPE_1
        attribute(:foo) { |type| MyDecorator.new(type) }
      end

      type = attributes["foo"].type

      assert_instance_of MyDecorator, type
      assert_same TYPE_1, type.subtype
    end

    test "type decorators can be stacked" do
      attributes = default_attributes_for do
        attribute :foo, TYPE_1
        attribute(:foo) { |type| MyDecorator.new(type) }
        attribute(:foo) { |type| MyOtherDecorator.new(type) }
      end

      type = attributes["foo"].type

      assert_instance_of MyOtherDecorator, type
      assert_instance_of MyDecorator, type.subtype
      assert_same TYPE_1, type.subtype.subtype
    end

    test "re-registering an attribute overrides previous type decorators" do
      attributes = default_attributes_for do
        attribute :foo, TYPE_1
        attribute(:foo) { |type| MyDecorator.new(type) }
        attribute :foo, TYPE_1
      end

      assert_same TYPE_1, attributes["foo"].type
    end

    test "attribute_types reflects registered attribute types" do
      klass = class_with { attribute :foo, TYPE_1 }
      assert_same TYPE_1, klass.attribute_types["foo"]
    end

    test "attribute_types returns the default type when key is missing" do
      klass = class_with { attribute :foo, TYPE_1 }
      assert_equal Type::Value.new, klass.attribute_types["bar"]
    end

    test "new attributes can be registered at any time" do
      klass = class_with { attribute :foo, TYPE_1 }
      assert_includes klass._default_attributes, "foo"
      assert_not_includes klass._default_attributes, "bar"
      assert_same TYPE_1, klass.attribute_types["foo"]

      klass.attribute :bar, TYPE_2
      assert_includes klass._default_attributes, "foo"
      assert_includes klass._default_attributes, "bar"
      assert_same TYPE_1, klass.attribute_types["foo"]
      assert_same TYPE_2, klass.attribute_types["bar"]
    end

    test "attributes are inherited" do
      parent = class_with do
        attribute :foo, TYPE_1, default: 123
        attribute(:foo) { |type| MyDecorator.new(type) }
      end

      child = Class.new(parent)

      parent_attribute = parent._default_attributes["foo"]
      child_attribute = child._default_attributes["foo"]

      assert_same parent_attribute.type.class, child_attribute.type.class ##################
      assert_same parent_attribute.type.subtype, child_attribute.type.subtype
      assert_same parent_attribute.value, child_attribute.value
    end

    test "subclass attributes do not affect superclass" do
      parent = class_with { attribute :foo }
      child = class_with(parent) { attribute :bar }

      assert_not_includes parent._default_attributes, "bar"
      assert_includes child._default_attributes, "bar"
    end

    test "new superclass attributes are inherited even after subclass attributes are registered" do
      parent = class_with { attribute :foo }
      child = class_with(parent) { attribute :bar }
      parent.attribute :qux

      assert_includes child._default_attributes, "qux"
    end

    test "new superclass attributes do not override subclass attributes" do
      parent = class_with { attribute :bar }
      child = class_with(parent) { attribute :foo, TYPE_1 }
      parent.attribute :foo, TYPE_2

      assert_same TYPE_1, child._default_attributes["foo"].type
    end

    test "superclass attributes can be overridden" do
      parent = class_with { attribute :foo, TYPE_1 }
      child = class_with(parent) { attribute :foo, TYPE_2 }

      assert_same TYPE_2, child._default_attributes["foo"].type
      assert_same TYPE_1, parent._default_attributes["foo"].type
    end

    test "superclass default values can be overridden" do
      parent = class_with do
        attribute :foo, TYPE_1, default: 123
        attribute :bar, TYPE_2
      end

      child = class_with(parent) do
        attribute :foo, default: 456
        attribute :bar, default: 789
      end

      assert_same TYPE_1, child._default_attributes["foo"].type
      assert_same TYPE_2, child._default_attributes["bar"].type
      assert_equal 456, child._default_attributes["foo"].value
      assert_equal 789, child._default_attributes["bar"].value
      assert_equal 123, parent._default_attributes["foo"].value
      assert_nil parent._default_attributes["bar"].value
    end

    test "superclass attribute types can be decorated" do
      parent = class_with { attribute :foo, TYPE_1 }
      child = class_with(parent) { attribute(:foo) { |type| MyDecorator.new(type) } }

      assert_instance_of MyDecorator, child._default_attributes["foo"].type
      assert_same TYPE_1, child._default_attributes["foo"].type.subtype
      assert_same TYPE_1, parent._default_attributes["foo"].type
    end

    private
      def class_with(base_class = nil, &block)
        Class.new(*base_class) do
          include AttributeRegistration
          instance_eval(&block)
        end
      end

      def default_attributes_for(&block)
        class_with(&block)._default_attributes
      end
  end
end

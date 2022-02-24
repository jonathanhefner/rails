# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/deep_dup"
require "active_model/attribute_set/builder"
require "active_model/attribute_set/yaml_encoder"

module ActiveModel
  class AttributeSet # :nodoc:
    delegate :each_value, :fetch, :except, to: :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def [](name)
      @attributes[name] || default_attribute(name)
    end

    def []=(name, value)
      @attributes[name] = value
    end

    def cast_types
      attributes.transform_values(&:type)
    end

    def values_before_type_cast
      attributes.transform_values(&:value_before_type_cast)
    end

    def values_for_database
      attributes.transform_values(&:value_for_database)
    end

    def to_hash
      keys.index_with { |name| self[name].value }
    end
    alias :to_h :to_hash

    def key?(name)
      attributes.key?(name) && self[name].initialized?
    end
    alias :include? :key?

    def keys
      attributes.each_key.select { |name| self[name].initialized? }
    end

    def fetch_value(name, &block)
      self[name].value(&block)
    end

    def write_from_database(name, value)
      @attributes[name] = self[name].with_value_from_database(value)
    end

    def write_from_user(name, value)
      raise FrozenError, "can't modify frozen attributes" if frozen?
      @attributes[name] = self[name].with_value_from_user(value)
      value
    end

    def write_cast_value(name, value)
      @attributes[name] = self[name].with_cast_value(value)
    end

    def freeze
      attributes.freeze
      super
    end

    def deep_dup
      AttributeSet.new(attributes.deep_dup)
    end

    def initialize_dup(_)
      @attributes = @attributes.dup
      super
    end

    def initialize_clone(_)
      @attributes = @attributes.clone
      super
    end

    def reset(key)
      if key?(key)
        write_from_database(key, nil)
      end
    end

    def accessed
      attributes.each_key.select { |name| self[name].has_been_read? }
    end

    def map(&block)
      dup.map!(&block)
    end

    def map!(&block)
      attributes.transform_values!(&block) && self
    end

    def revise_types!(&block)
      map! do |attribute|
        type = block.call(attribute.name, attribute.type)
        (type.nil? || attribute.type.equal?(type)) ? attribute : attribute.with_type(type)
      end
    end

    def merge!(other, &block)
      attributes.merge!(other.attributes, &block) && self
    end

    def ==(other)
      attributes == other.attributes
    end

    protected
      attr_reader :attributes

    private
      def default_attribute(name)
        Attribute.null(name)
      end
  end
end

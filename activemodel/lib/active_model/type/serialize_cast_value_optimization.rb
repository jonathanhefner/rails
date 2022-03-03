# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValueOptimization # :nodoc:
      def self.included(klass)
        klass.singleton_class.attr_accessor :serialize_cast_value_optimization_included
        klass.serialize_cast_value_optimization_included = true
      end

      def initialize(...)
        super
        @serialize_cast_value_optimization_included = self.class.serialize_cast_value_optimization_included
      end

      def serialize_cast_value(value)
        value
      end

      def optimally_serialize_cast_value(value)
        @serialize_cast_value_optimization_included ? serialize_cast_value(value) : serialize(value)
      end
    end
  end
end

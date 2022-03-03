# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValue # :nodoc:
      def self.included(klass)
        klass.singleton_class.attr_accessor :serialize_cast_value_included
        klass.serialize_cast_value_included = true
      end

      def self.serialize(type, value)
        if SerializeCastValue === type && type.serialize_cast_value_included
          type.serialize_cast_value(value)
        else
          type.serialize(value)
        end
      end

      attr_reader :serialize_cast_value_included

      def initialize(...)
        super
        @serialize_cast_value_included = self.class.serialize_cast_value_included
      end

      def serialize_cast_value(value)
        value
      end
    end
  end
end

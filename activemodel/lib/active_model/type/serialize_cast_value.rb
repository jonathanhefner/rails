# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValue # :nodoc:
      def self.included(klass)
        klass.singleton_class.attr_accessor :serialize_cast_value_included
        klass.serialize_cast_value_included = true
        klass.attr_reader :itself_if_serialize_cast_value_included
      end

      def self.serialize(type, value)
        use_serialize_cast_value = begin
          type.equal?(type.itself_if_serialize_cast_value_included)
        rescue NoMethodError
          false
        end

        use_serialize_cast_value ? type.serialize_cast_value(value) : type.serialize(value)
      end

      def initialize(...)
        super
        @itself_if_serialize_cast_value_included = self if self.class.serialize_cast_value_included
      end

      def serialize_cast_value(value)
        value
      end
    end
  end
end

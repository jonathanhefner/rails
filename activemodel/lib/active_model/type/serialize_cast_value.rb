# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValue # :nodoc:
      def self.included(klass)
        klass.alias_method :itself_if_serialize_cast_value_included, :itself
        klass.extend(ClassMethods)
      end

      module ClassMethods
        def inherited(subclass)
          subclass.alias_method :itself_if_serialize_cast_value_included, :!
          super
        end
      end

      def self.serialize(type, value)
        use_serialize_cast_value = begin
          type.equal?(type.itself_if_serialize_cast_value_included)
        rescue NoMethodError
          false
        end

        use_serialize_cast_value ? type.serialize_cast_value(value) : type.serialize(value)
      end

      def serialize_cast_value(value)
        value
      end
    end
  end
end

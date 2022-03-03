# frozen_string_literal: true

module ActiveModel
  module Type
    module SerializeCastValueOptimization # :nodoc:
      extend ActiveSupport::Concern

      included do
        alias_method :optimized_serialize_cast_value, :call_serialize_cast_value
      end

      module ClassMethods
        def inherited(subclass)
          super
          subclass.alias_method :optimized_serialize_cast_value, :call_serialize
        end
      end

      def serialize_cast_value(value)
        value
      end

      # Provides late binding to +serialize_cast_value+.
      def call_serialize_cast_value(value)
        serialize_cast_value(value)
      end

      # Provides late binding to +call_serialize+.
      def call_serialize(value)
        serialize(value)
      end
    end
  end
end

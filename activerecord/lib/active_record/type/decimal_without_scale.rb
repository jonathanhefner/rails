# frozen_string_literal: true

module ActiveRecord
  module Type
    class DecimalWithoutScale < ActiveModel::Type::BigInteger # :nodoc:
      inherits_serialize_cast_value_optimization

      def type
        :decimal
      end

      def type_cast_for_schema(value)
        value.to_s.inspect
      end
    end
  end
end

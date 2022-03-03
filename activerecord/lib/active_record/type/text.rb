# frozen_string_literal: true

module ActiveRecord
  module Type
    class Text < ActiveModel::Type::String # :nodoc:
      inherits_serialize_cast_value_optimization

      def type
        :text
      end

      public :serialize_cast_value # :nodoc:
    end
  end
end

# frozen_string_literal: true

module ActiveRecord
  module Type
    class UnsignedInteger < ActiveModel::Type::Integer # :nodoc:
      alias serialize_after_cast serialize_after_cast # :nodoc:

      private
        def max_value
          super * 2
        end

        def min_value
          0
        end
    end
  end
end

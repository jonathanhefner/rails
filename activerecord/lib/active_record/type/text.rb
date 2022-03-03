# frozen_string_literal: true

module ActiveRecord
  module Type
    class Text < ActiveModel::Type::String # :nodoc:
      def type
        :text
      end

      alias serialize_after_cast serialize_after_cast # :nodoc:
    end
  end
end

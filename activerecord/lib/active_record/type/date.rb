# frozen_string_literal: true

module ActiveRecord
  module Type
    class Date < ActiveModel::Type::Date
      include Internal::Timezone

      alias serialize_after_cast serialize_after_cast # :nodoc:
    end
  end
end

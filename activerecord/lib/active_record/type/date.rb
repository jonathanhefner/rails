# frozen_string_literal: true

module ActiveRecord
  module Type
    class Date < ActiveModel::Type::Date
      include Internal::Timezone
      public :serialize_cast_value # :nodoc:
    end
  end
end

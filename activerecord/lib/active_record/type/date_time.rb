# frozen_string_literal: true

module ActiveRecord
  module Type
    class DateTime < ActiveModel::Type::DateTime
      include Internal::Timezone
      public :serialize_cast_value # :nodoc:
    end
  end
end

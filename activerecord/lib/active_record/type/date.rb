# frozen_string_literal: true

module ActiveRecord
  module Type
    class Date < ActiveModel::Type::Date
      include Internal::Timezone
      inherits_serialize_cast_value_optimization
    end
  end
end

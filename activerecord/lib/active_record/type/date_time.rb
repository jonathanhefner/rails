# frozen_string_literal: true

module ActiveRecord
  module Type
    class DateTime < ActiveModel::Type::DateTime
      include Internal::Timezone

      alias serialize_after_cast serialize_after_cast # :nodoc:
    end
  end
end

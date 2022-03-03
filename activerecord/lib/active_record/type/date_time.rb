# frozen_string_literal: true

module ActiveRecord
  module Type
    class DateTime < ActiveModel::Type::DateTime
      include ActiveModel::Type::SerializeCastValueOptimization
      include Internal::Timezone
    end
  end
end

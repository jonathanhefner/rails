# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/hash/indifferent_access"

module ActiveModel
  module Access
    # Returns a hash of the given methods with their names as keys and returned
    # values as values.
    def slice(*methods)
      methods.flatten.index_with { |method| public_send(method) }.with_indifferent_access
    end

    # Returns an array of the values returned by the given methods.
    def values_at(*methods)
      methods.flatten.map! { |method| public_send(method) }
    end
  end
end

# frozen_string_literal: true

require_relative "metadata"
require_relative "serializer_with_fallback"

module ActiveSupport
  module Messages # :nodoc:
    class Codec # :nodoc:
      include Metadata

      class_attribute :default_serializer, default: :marshal,
        instance_accessor: false, instance_predicate: false

      def initialize(serializer: self.class.default_serializer, url_safe: false)
        @serializer = serializer.is_a?(Symbol) ? SerializerWithFallback[serializer] : serializer
        @url_safe = url_safe
      end

      private
        attr_reader :serializer

        def encode(data, url_safe: @url_safe)
          url_safe ? ::Base64.urlsafe_encode64(data, padding: false) : ::Base64.strict_encode64(data)
        end

        def decode(encoded, url_safe: @url_safe)
          url_safe ? ::Base64.urlsafe_decode64(encoded) : ::Base64.strict_decode64(encoded)
        rescue ArgumentError => error
          throw :invalid_message_format, error
        end

        def serialize(data)
          serializer.dump(data)
        end

        def deserialize(serialized)
          serializer.load(serialized)
        rescue StandardError => error
          throw :invalid_message_serialization, error
        end

        def catch_and_ignore(throwable, &block)
          catch throwable do
            return block.call
          end
          nil
        end

        def catch_and_raise(throwable, as: nil, &block)
          error = catch throwable do
            return block.call
          end
          error = as.new(error.to_s) if as
          raise error
        end
    end
  end
end

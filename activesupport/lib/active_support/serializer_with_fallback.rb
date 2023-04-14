# frozen_string_literal: true

module ActiveSupport
  module SerializerWithFallback # :nodoc:
    singleton_class.attr_accessor :marshal_fallback

    def self.[](format)
      case format
      when :marshal
        MarshalWithFallback
      when :json
        JsonWithFallback
      when :message_pack
        require "active_support/message_pack" unless defined?(ActiveSupport::MessagePack)
        MessagePackWithFallback
      else
        raise "TODO invalid format: #{format.inspect}"
      end
    end

    def load(dumped)
      case
      when MessagePackWithFallback.dumped?(dumped)
        MessagePackWithFallback._load(dumped)
      when MarshalWithFallback.dumped?(dumped)
        marshal_load(dumped)
      when JsonWithFallback.dumped?(dumped)
        JsonWithFallback._load(dumped)
      else
        # Try JSON in case the JSON regexp produced a false negative.
        begin
          JsonWithFallback._load(dumped)
        rescue ::JSON::ParserError
          raise "TODO invalid dump: #{dumped.inspect}"
        end
      end
    end

    def marshal_load(dumped)
      if SerializerWithFallback.marshal_fallback
        if SerializerWithFallback.marshal_fallback == :log && defined?(Rails.logger)
          Rails.logger.warn("TODO Marshal load fallback occurred")
        end
        MarshalWithFallback._load(dumped)
      else
        raise "TODO Marshal load fallback disabled"
      end
    end

    module MarshalWithFallback
      include SerializerWithFallback
      extend self

      def dump(object)
        ::Marshal.dump(object)
      end

      def _load(dumped)
        ::Marshal.load(dumped)
      end

      alias :marshal_load :_load

      MARSHAL_SIGNATURE = "\x04\x08"

      def dumped?(dumped)
        dumped.start_with?(MARSHAL_SIGNATURE)
      end
    end

    module JsonWithFallback
      include SerializerWithFallback
      extend self

      def dump(object)
        ActiveSupport::JSON.encode(object)
      end

      def _load(dumped)
        ActiveSupport::JSON.decode(dumped)
      end

      JSON_START_WITH = /\A(?:[{\["]|-?\d|true|false)/

      def dumped?(dumped)
        JSON_START_WITH.match?(dumped)
      end
    end

    module MessagePackWithFallback
      include SerializerWithFallback
      extend self

      def dump(object)
        ActiveSupport::MessagePack.dump(object)
      end

      def _load(dumped)
        ActiveSupport::MessagePack.load(dumped)
      end

      def dumped?(dumped)
        available? && ActiveSupport::MessagePack.signature?(dumped)
      end

      def available?
        return @available if defined?(@available)
        require "active_support/message_pack" unless defined?(ActiveSupport::MessagePack)
        @available = true
      rescue LoadError
        @available = false
      end
    end
  end
end

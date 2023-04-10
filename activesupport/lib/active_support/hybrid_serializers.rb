# frozen_string_literal: true

module ActiveSupport
  module HybridSerializers # :nodoc:
    def self.[](name)
      case name
      when :marshal
        HybridMarshal
      when :json
        HybridJSON
      when :message_pack
        require "active_support/message_pack"
        HybridMessagePack
      else
        raise "TODO"
      end
    end

    module HybridLoader
      def self.fallbacks
        @fallbacks ||= []
      end

      def load(dumped)
        _load(dumped) { |result| return result }
        HybridLoader.fallbacks.each do |fallback|
          fallback._load(dumped) { |result| return result } unless fallback == self
        end
        raise "TODO"
      end
    end

    module HybridMarshal
      include HybridLoader
      extend self

      def dump(object)
        ::Marshal.dump(object)
      end

      def _load(dumped)
        yield ::Marshal.load(dumped) if dumped?(dumped)
      end

      MARSHAL_SIGNATURE = "\x04\x08"

      def dumped?(dumped)
        dumped.start_with?(MARSHAL_SIGNATURE)
      end

      HybridLoader.fallbacks.unshift HybridMarshal
    end

    module HybridJSON
      include HybridLoader
      extend self

      def dump(object)
        ActiveSupport::JSON.encode(object)
      end

      def _load(dumped)
        yield ActiveSupport::JSON.decode(dumped)
      rescue ::JSON::ParserError
        # Treat as unrecognized format.
      end

      JSON_START_WITH = /\A(?:[{\["]|-?\d|true|false)/

      def dumped?(dumped)
        JSON_START_WITH.match?(dumped)
      end

      # Register HybridJSON as the last fallback because it is more expensive to
      # detect a JSON payload.
      HybridLoader.fallbacks << HybridJSON
    end

    module HybridMessagePack
      include HybridLoader
      extend self

      def dump(object)
        ActiveSupport::MessagePack.dump(object)
      end

      def _load(dumped)
        yield ActiveSupport::MessagePack.load(dumped) if dumped?(dumped)
      end

      def dumped?(dumped)
        ActiveSupport::MessagePack.signature?(dumped)
      end

      ActiveSupport.on_load(:message_pack) { HybridLoader.fallbacks.unshift HybridMessagePack }
    end
  end
end

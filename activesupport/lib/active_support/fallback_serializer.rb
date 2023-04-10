# frozen_string_literal: true

module ActiveSupport
  module FallbackSerializer # :nodoc:
    def self.[](name)
      case name
      when :marshal
        FallbackSerializer::Marshal
      when :json
        FallbackSerializer::JSON
      when :message_pack
        require "active_support/message_pack"
        FallbackSerializer::MessagePack
      else
        raise "TODO"
      end
    end

    def self.loaders
      @loaders ||= []
    end

    def load(dumped, first_try: self)
      first_try&._load(dumped) { |result| return result }
      FallbackSerializer.loaders.each do |loader|
        loader._load(dumped) { |result| return result } unless loader == first_try
      end
      raise "TODO"
    end

    module Marshal
      include FallbackSerializer
      extend self
      FallbackSerializer.loaders.unshift(self)

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
    end

    module JSON
      include FallbackSerializer
      extend self
      # Register as the last loader because it's more expensive to detect JSON.
      FallbackSerializer.loaders << self

      def dump(object)
        ActiveSupport::JSON.encode(object)
      end

      def _load(dumped)
        yield ActiveSupport::JSON.decode(dumped)
      rescue ::JSON::ParserError
        # Treat as unrecognized format.
      end

      def load(dumped)
        super(dumped, first_try: nil)
      end

      JSON_START_WITH = /\A(?:[{\["]|-?\d|true|false)/

      def dumped?(dumped)
        JSON_START_WITH.match?(dumped)
      end
    end

    module MessagePack
      include FallbackSerializer
      extend self
      # TODO must trigger this if gem is in Gemfile
      ActiveSupport.on_load(:message_pack) { FallbackSerializer.loaders.unshift(MessagePack) }

      def dump(object)
        ActiveSupport::MessagePack.dump(object)
      end

      def _load(dumped)
        yield ActiveSupport::MessagePack.load(dumped) if dumped?(dumped)
      end

      def dumped?(dumped)
        ActiveSupport::MessagePack.signature?(dumped)
      end
    end
  end
end

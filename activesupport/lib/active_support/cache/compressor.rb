# frozen_string_literal: true

require "zlib"

module ActiveSupport
  module Cache
    module Compressor # :nodoc:
      extend self

      def compress(string)
        Zlib::Deflate.deflate(string)
      end

      def decompress(compressed)
        Zlib::Inflate.inflate(compressed)
      end
    end
  end
end

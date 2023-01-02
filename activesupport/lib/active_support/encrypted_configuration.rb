# frozen_string_literal: true

require "yaml"
require "active_support/encrypted_file"
require "active_support/ordered_options"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/module/delegation"

module ActiveSupport
  class EncryptedConfiguration < EncryptedFile
    class InvalidContentError < RuntimeError
      def initialize(content_path)
        super "Invalid YAML in '#{content_path}'."
      end

      def message
        cause.is_a?(Psych::SyntaxError) ? "#{super}\n\n  #{cause.message}" : super
      end
    end

    delegate :[], :fetch, to: :config
    delegate_missing_to :options

    def initialize(config_path:, key_path:, env_key:, raise_if_missing_key:)
      super content_path: config_path, key_path: key_path,
        env_key: env_key, raise_if_missing_key: raise_if_missing_key
    end

    # Reads the file and returns the decrypted content. See EncryptedFile#read.
    def read
      super
    rescue ActiveSupport::EncryptedFile::MissingContentError
      # Allow a config to be started without a file present
      ""
    end

    def validate! # :nodoc:
      deserialize(read)
    end

    def config
      @config ||= deserialize(read).deep_symbolize_keys
    end

    private
      def deep_transform(hash)
        return hash unless hash.is_a?(Hash)

        h = ActiveSupport::InheritableOptions.new
        hash.each do |k, v|
          h[k] = deep_transform(v)
        end
        h
      end

      def options
        @options ||= ActiveSupport::InheritableOptions.new(deep_transform(config))
      end

      def deserialize(content)
        config = YAML.respond_to?(:unsafe_load) ?
          YAML.unsafe_load(content, filename: content_path) :
          YAML.load(content, filename: content_path)

        config.presence || {}
      rescue Psych::SyntaxError
        raise InvalidContentError.new(content_path)
      end
  end
end

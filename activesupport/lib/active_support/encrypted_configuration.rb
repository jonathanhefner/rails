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

    ##
    # :call-seq:
    #   [](key)
    #
    # Returns the decrypted value corresponding to a given key. The key should
    # be symbol.
    #
    #   my_config = ActiveSupport::EncryptedConfiguration.new(...)
    #   my_config.read # => "abc: 123\n"
    #
    #   my_config[:abc]
    #   # => 123
    #   my_config[:foo]
    #   # => nil
    #
    delegate :[], to: :config

    ##
    # :call-seq:
    #   fetch(key)
    #   fetch(key, default)
    #   fetch(key, &block)
    #
    # Returns the decrypted value corresponding to a given key. The key should
    # be symbol. If the key does not have a corresponding value, returns the
    # given default, or raises a +KeyError+ if no default was given. See also
    # <tt>Hash#fetch</tt>.
    #
    #   my_config = ActiveSupport::EncryptedConfiguration.new(...)
    #   my_config.read # => "abc: 123\n"
    #
    #   my_config.fetch(:abc)
    #   # => 123
    #   my_config.fetch(:foo)
    #   # => KeyError
    #   my_config.fetch(:foo, "bar")
    #   # => "bar"
    #   my_config.fetch(:foo) { |key| key.to_s }
    #   # => "foo"
    #
    delegate :fetch, to: :config

    delegate_missing_to :options

    def initialize(config_path:, key_path:, env_key:, raise_if_missing_key:)
      super content_path: config_path, key_path: key_path,
        env_key: env_key, raise_if_missing_key: raise_if_missing_key
    end

    # Allow a config to be started without a file present
    def read
      super
    rescue ActiveSupport::EncryptedFile::MissingContentError
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

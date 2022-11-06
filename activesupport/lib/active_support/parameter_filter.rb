# frozen_string_literal: true

require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/array/extract"

module ActiveSupport
  # +ParameterFilter+ allows you to specify keys for sensitive data from
  # hash-like object and replace corresponding value. Filtering only certain
  # sub-keys from a hash is possible by using the dot notation:
  # 'credit_card.number'. If a proc is given, each key and value of a hash and
  # all sub-hashes are passed to it, where the value or the key can be replaced
  # using String#replace or similar methods.
  #
  #   ActiveSupport::ParameterFilter.new([:password])
  #   => replaces the value to all keys matching /password/i with "[FILTERED]"
  #
  #   ActiveSupport::ParameterFilter.new([:foo, "bar"])
  #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
  #
  #   ActiveSupport::ParameterFilter.new([/\Apin\z/i, /\Apin_/i])
  #   => replaces the value for the exact (case-insensitive) key 'pin' and all
  #   (case-insensitive) keys beginning with 'pin_', with "[FILTERED]".
  #   Does not match keys with 'pin' as a substring, such as 'shipping_id'.
  #
  #   ActiveSupport::ParameterFilter.new(["credit_card.code"])
  #   => replaces { credit_card: {code: "xxxx"} } with "[FILTERED]", does not
  #   change { file: { code: "xxxx"} }
  #
  #   ActiveSupport::ParameterFilter.new([-> (k, v) do
  #     v.reverse! if /secret/i.match?(k)
  #   end])
  #   => reverses the value to all keys matching /secret/i
  class ParameterFilter
    FILTERED = "[FILTERED]" # :nodoc:

    # Create instance with given filters. Supported type of filters are +String+, +Regexp+, and +Proc+.
    # Other types of filters are treated as +String+ using +to_s+.
    # For +Proc+ filters, key, value, and optional original hash is passed to block arguments.
    #
    # ==== Options
    #
    # * <tt>:mask</tt> - A replaced object when filtered. Defaults to <tt>"[FILTERED]"</tt>.
    def initialize(filters = [], mask: FILTERED)
      @filters = filters
      @mask = mask
    end

    # Mask value of +params+ if key matches one of filters.
    def filter(params)
      compiled_filter.call(params)
    end

    # Returns filtered value for given key. For +Proc+ filters, third block argument is not populated.
    def filter_param(key, value)
      @filters.empty? ? value : compiled_filter.value_for_key(key, value)
    end

  private
    def compiled_filter
      @compiled_filter ||= CompiledFilter.compile(@filters, mask: @mask)
    end

    class CompiledFilter # :nodoc:
      def self.compile(filters, mask:)
        return lambda { |params| params.dup } if filters.empty?

        blocks, patterns = nil, []

        filters.each do |item|
          case item
          when Proc
            (blocks ||= []) << item
          when Regexp
            patterns << item
          else
            patterns << "(?i-mx:#{Regexp.escape item.to_s})"
          end
        end

        deep_patterns = patterns.extract! { |pattern| pattern.to_s.include?("\\.") }

        regexp = Regexp.new(patterns.join("|")) if patterns.any?
        deep_regexp = Regexp.new(deep_patterns.join("|")) if deep_patterns.any?

        new regexp, deep_regexp, blocks, mask: mask
      end

      def initialize(regexp, deep_regexp, blocks, mask:)
        @regexp = regexp
        @deep_regexp = deep_regexp
        @blocks = blocks
        @mask = mask
      end

      def call(params, full_parent_key = nil, original_params = params)
        filtered_params = params.class.new

        params.each do |key, value|
          filtered_params[key] = value_for_key(key, value, full_parent_key, original_params)
        end

        filtered_params
      end

      def value_for_key(key, value, full_parent_key = nil, original_params = nil)
        if @deep_regexp
          full_key = full_parent_key ? "#{full_parent_key}.#{key}" : key.to_s
        end

        case
        when @regexp&.match?(key.to_s) || @deep_regexp&.match?(full_key)
          @mask
        when value.is_a?(Hash)
          call(value, full_key, original_params)
        when value.is_a?(Array)
          value.map { |v| value_for_key(key, v, full_parent_key, original_params) }
        when @blocks
          value = value.dup if value.duplicable?
          @blocks.each { |b| b.arity == 2 ? b.call(key, value) : b.call(key, value, original_params) }
          value
        else
          value
        end
      end
    end
  end
end

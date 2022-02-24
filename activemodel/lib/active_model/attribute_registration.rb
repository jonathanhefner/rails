# frozen_string_literal: true

require "active_support/core_ext/class/subclasses"
require "active_model/attribute_set"
require "active_model/attribute/user_provided_default"

module ActiveModel
  module AttributeRegistration # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods # :nodoc:
      def attribute(name, type = nil, default: NO_DEFAULT_PROVIDED, **options, &block)
        name = resolve_attribute_name(name)

        if type
          type = resolve_attribute_type(type, **options) if type.is_a?(Symbol)
          @attribute_type_decorators&.delete(name)
        else
          type = pending_attributes[name].type
        end

        pending_attributes[name] = pending_attributes[name].with_type(type)
        pending_attributes[name] = pending_attributes[name].with_user_default(default) if default != NO_DEFAULT_PROVIDED

        if block
          @attribute_type_decorators ||= {}
          @attribute_type_decorators[name] = [@attribute_type_decorators[name], block].compact.reduce(&:>>)
        end

        reset_default_attributes
      end

      def _default_attributes # :nodoc:
        @default_attributes ||= build_default_attributes
      end

      def attribute_types # :nodoc:
        @attribute_types ||= _default_attributes.cast_types.tap do |hash|
          hash.default = Type.default_value
        end
      end

      def reset_default_attributes # :nodoc:
        @default_attributes = nil
        @attribute_types = nil
        subclasses.each(&__method__)
      end

      def apply_pending_attributes(attribute_set) # :nodoc:
        superclass.apply_pending_attributes(attribute_set) if superclass.respond_to?(:apply_pending_attributes)

        if @pending_attributes
          attribute_set.merge!(@pending_attributes) do |name, attribute, pending|
            attribute = attribute.with_type(pending.type) unless pending.type.equal?(Type.default_value)
            attribute = attribute.with_user_default(pending.user_provided_value) if pending.is_a?(Attribute::UserProvidedDefault)
            attribute
          end
        end

        attribute_set.revise_types! do |name, type|
          @attribute_type_decorators[name].call(type) if @attribute_type_decorators&.key?(name)
        end
      end

      private
        NO_DEFAULT_PROVIDED = Object.new # :nodoc:

        def pending_attributes
          @pending_attributes ||= AttributeSet.new({})
        end

        def build_default_attributes
          apply_pending_attributes(AttributeSet.new({}))
        end

        def resolve_attribute_name(name)
          name.to_s
        end

        def resolve_attribute_type(type, **options)
          Type.lookup(type, **options)
        end
    end
  end
end

# frozen_string_literal: true

require "active_support/core_ext/class/subclasses"
require "active_model/attribute_set"
require "active_model/attribute/user_provided_default"

module ActiveModel
  module AttributeRegistration # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods # :nodoc:
      def attribute(name, type = nil, default: (no_default = true), **options, &block)
        type = resolve_attribute_type(type, **options) if type.is_a?(Symbol)

        pending = pending_attributes[resolve_attribute_name(name)]
        pending.type = type if type
        pending.default = default unless no_default
        pending.decorate(&block) if block

        reset_default_attributes
      end

      def decorate_attribute(name, decorator, **options)
        pending_attributes[resolve_attribute_name(name)].decorate do |type|
          resolve_attribute_type(decorator, **options, subtype: type)
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

      private
        class PendingAttribute # :nodoc:
          attr_accessor :default, :decorator

          def type=(type)
            self.decorator = nil
            @type = type
          end
          attr_reader :type

          def decorate(&decorator)
            if type
              self.type = decorator.call(type)
            else
              self.decorator = [self.decorator, decorator].compact.reduce(&:>>)
            end
          end

          def apply_to(attribute)
            attribute = attribute.with_type(type || decorator&.call(attribute.type) || attribute.type)
            attribute = attribute.with_user_default(default) if defined?(@default)
            attribute
          end
        end

        def pending_attributes
          @pending_attributes ||= Hash.new { |hash, key| hash[key] = PendingAttribute.new }
        end

        def build_default_attributes
          apply_pending_attributes(AttributeSet.new({}))
        end

        def apply_pending_attributes(attribute_set)
          superclass.send(__method__, attribute_set) if superclass.respond_to?(__method__, true)

          @pending_attributes&.each do |name, pending|
            attribute_set[name] = pending.apply_to(attribute_set[name])
          end

          attribute_set
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

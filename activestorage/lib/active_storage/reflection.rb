# frozen_string_literal: true

module ActiveStorage
  module Reflection
    class PredefinedTransformations # :nodoc:
      attr_reader :transformations

      def initialize(transformations, preprocess)
        @transformations = transformations
        @preprocess = preprocess
      end

      def preprocess_for?(record)
        case @preprocess
        when Symbol
          record.send(@preprocess)
        when Proc
          @preprocess.call(record)
        else
          @preprocess
        end
      end
    end

    class HasAttachedReflection < ActiveRecord::Reflection::MacroReflection # :nodoc:
      def variant(name, transformations)
        transformations = transformations.dup
        preprocess = transformations.delete(:preprocessed)
        predefined_transformations[name] = PredefinedTransformations.new(transformations, preprocess)
      end

      def predefined_transformations
        @predefined_transformations ||= {}
      end
    end

    # Holds all the metadata about a has_one_attached attachment as it was
    # specified in the Active Record class.
    class HasOneAttachedReflection < HasAttachedReflection # :nodoc:
      def macro
        :has_one_attached
      end
    end

    # Holds all the metadata about a has_many_attached attachment as it was
    # specified in the Active Record class.
    class HasManyAttachedReflection < HasAttachedReflection # :nodoc:
      def macro
        :has_many_attached
      end
    end

    module ReflectionExtension # :nodoc:
      def add_attachment_reflection(model, name, reflection)
        model.attachment_reflections = model.attachment_reflections.merge(name.to_s => reflection)
      end

      private
        def reflection_class_for(macro)
          case macro
          when :has_one_attached
            HasOneAttachedReflection
          when :has_many_attached
            HasManyAttachedReflection
          else
            super
          end
        end
    end

    module ActiveRecordExtensions
      extend ActiveSupport::Concern

      included do
        class_attribute :attachment_reflections, instance_writer: false, default: {}
      end

      module ClassMethods
        # Returns an array of reflection objects for all the attachments in the
        # class.
        def reflect_on_all_attachments
          attachment_reflections.values
        end

        # Returns the reflection object for the named +attachment+.
        #
        #    User.reflect_on_attachment(:avatar)
        #    # => the avatar reflection
        #
        def reflect_on_attachment(attachment)
          attachment_reflections[attachment.to_s]
        end
      end
    end
  end
end

# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module Normalization
    extend ActiveSupport::Concern

    included do
      class_attribute :normalized_attributes, default: Set.new

      before_validation :normalize_changed_in_place_attributes
    end

    # Normalizes a specified attribute using its declared normalizations.
    #
    # ==== Examples
    #
    #   class User < ActiveRecord::Base
    #     normalizes :email, with: -> email { email.strip.downcase }
    #   end
    #
    #   legacy_user = User.find(1)
    #   legacy_user.email # => " CRUISE-CONTROL@EXAMPLE.COM\n"
    #   legacy_user.normalize_attribute(:email)
    #   legacy_user.email # => "cruise-control@example.com"
    #   legacy_user.save
    def normalize_attribute(name)
      # Treat the value as a new, unnormalized value.
      self[name] = self[name]
    end

    module ClassMethods
      # Declares a normalization for one or more attributes. The normalization
      # is applied when the attribute is assigned or updated, and the normalized
      # value will be persisted to the database. The normalization is also
      # applied to the corresponding keyword argument of query methods. This
      # allows a record to be created and later queried using unnormalized
      # values.
      #
      # However, to prevent confusion, the normalization will not be applied
      # when the attribute is fetched from the database. This means that if a
      # record was persisted before the normalization was declared, the record's
      # attribute will not be normalized until either it is assigned a new
      # value, or it is explicitly migrated via Normalization#normalize_attribute.
      #
      # Because the normalization may be applied multiple times, it should be
      # _idempotent_. In other words, applying the normalization more than once
      # should have the same result as applying it only once.
      #
      # By default, the normalization will not be applied to +nil+ values. This
      # behavior can be changed with the +:apply_to_nil+ option.
      #
      # ==== Options
      #
      # * +:with+ - Any callable object that accepts the attribute's value as
      #   its sole argument, and returns it normalized.
      # * +:apply_to_nil+ - Whether to apply the normalization to +nil+ values.
      #   Defaults to +false+.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     normalizes :email, with: -> email { email.strip.downcase }
      #     normalizes :phone, with: -> phone { phone.delete("^0-9").delete_prefix("1") }
      #   end
      #
      #   user = User.create(email: " CRUISE-CONTROL@EXAMPLE.COM\n")
      #   user.email                  # => "cruise-control@example.com"
      #
      #   user = User.find_by(email: "\tCRUISE-CONTROL@EXAMPLE.COM ")
      #   user.email                  # => "cruise-control@example.com"
      #   user.email_before_type_cast # => "cruise-control@example.com"
      #
      #   User.where(email: "\tCRUISE-CONTROL@EXAMPLE.COM ").count         # => 1
      #   User.where(["email = ?", "\tCRUISE-CONTROL@EXAMPLE.COM "]).count # => 0
      #
      #   User.exists?(email: "\tCRUISE-CONTROL@EXAMPLE.COM ")         # => true
      #   User.exists?(["email = ?", "\tCRUISE-CONTROL@EXAMPLE.COM "]) # => false
      #
      #   User.normalize_value_for(:phone, "+1 (555) 867-5309") # => "5558675309"
      def normalizes(*names, with:, apply_to_nil: false)
        decorate_attributes(names) do |name, cast_type|
          NormalizedValueType.new(cast_type: cast_type, normalizer: with, normalize_nil: apply_to_nil)
        end

        self.normalized_attributes += names.map { |name| resolve_attribute_name(name) }
      end

      # Similar to #normalizes, but normalizes attributes of the specified types.
      #
      #   class Snippet < ActiveRecord::Base
      #     normalizes_attributes_of_type :string, :text, except: [:code], with: -> { _1.strip }
      #   end
      #
      #   snippet = Snippet.create(title: "  Title", description: "Description.\n", code: "  code\n")
      #   snippet.title        # => "Title"
      #   snippet.description  # => "Description."
      #   snippet.code         # => "  code\n"
      #
      # The normalization is applied to matching attributes from the model
      # schema plus any attributes declared via
      # {attribute}[rdoc-ref:ActiveRecord::Attributes::ClassMethods#attribute]
      # _prior to_ the call to +normalizes_attributes_of_type+. Attributes
      # declared after the call to +normalizes_attributes_of_type+ will not be
      # affected. This behavior can be used to override a normalization from a
      # parent class by redeclaring an attribute:
      #
      #   class ApplicationRecord < ActiveRecord::Base
      #     normalizes_attributes_of_type :string, :text, with: -> { _1.strip }
      #   end
      #
      #   class Snippet < ApplicationRecord
      #     attribute :code, :text
      #   end
      #
      #   snippet = Snippet.create(title: "  Title", description: "Description.\n", code: "  code\n")
      #   snippet.title        # => "Title"
      #   snippet.description  # => "Description."
      #   snippet.code         # => "  code\n"
      #
      # ==== Options
      #
      # * +:except+ - Attributes to exclude from normalization. Can be a single
      #   name or an array of names.
      # * +:with+ - Any callable object that accepts the attribute's value as
      #   its sole argument, and returns it normalized.
      # * +:apply_to_nil+ - Whether to apply the normalization to +nil+ values.
      #   Defaults to +false+.
      #
      def normalizes_attributes_of_type(*types, except: nil, with:, apply_to_nil: false)
        except = Array(except).map { |name| resolve_attribute_name(name) }

        decorate_attributes do |name, cast_type|
          if types.include?(cast_type.type) && !except.include?(name)
            self.normalized_attributes += [name]
            NormalizedValueType.new(cast_type: cast_type, normalizer: with, normalize_nil: apply_to_nil)
          end
        end
      end

      # Normalizes a given +value+ using normalizations declared for +name+.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     normalizes :email, with: -> email { email.strip.downcase }
      #   end
      #
      #   User.normalize_value_for(:email, " CRUISE-CONTROL@EXAMPLE.COM\n")
      #   # => "cruise-control@example.com"
      def normalize_value_for(name, value)
        type_for_attribute(name).cast(value)
      end
    end

    private
      def normalize_changed_in_place_attributes
        self.class.normalized_attributes.each do |name|
          normalize_attribute(name) if attribute_changed_in_place?(name)
        end
      end

      class NormalizedValueType < DelegateClass(ActiveModel::Type::Value) # :nodoc:
        include ActiveModel::Type::SerializeCastValue

        attr_reader :cast_type, :normalizer, :normalize_nil
        alias :normalize_nil? :normalize_nil

        def initialize(cast_type:, normalizer:, normalize_nil:)
          @cast_type = cast_type
          @normalizer = normalizer
          @normalize_nil = normalize_nil
          super(cast_type)
        end

        def cast(value)
          normalize(super(value))
        end

        def serialize(value)
          serialize_cast_value(cast(value))
        end

        def serialize_cast_value(value)
          ActiveModel::Type::SerializeCastValue.serialize(cast_type, value)
        end

        def ==(other)
          self.class == other.class &&
            normalize_nil? == other.normalize_nil? &&
            normalizer == other.normalizer &&
            cast_type == other.cast_type
        end
        alias eql? ==

        def hash
          [self.class, cast_type, normalizer, normalize_nil?].hash
        end

        def inspect
          Kernel.instance_method(:inspect).bind_call(self)
        end

        private
          def normalize(value)
            normalizer.call(value) unless value.nil? && !normalize_nil?
          end
      end
  end
end

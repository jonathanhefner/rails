# frozen_string_literal: true

module ActiveRecord # :nodoc:
  # = Active Record \Normalization
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
      # Set the "changed" flag to trigger a type cast.
      self[name] = self[name]
    end

    module ClassMethods
      # Declares a normalization to apply to one or more attributes.
      # Normalizations are applied when the attributes are assigned or updated,
      # and the normalized values will be persisted to the database.
      # Normalizations are also applied to matching keyword arguments of finder
      # methods. This allows a record to be created and later queried using an
      # unnormalized value.
      #
      # However, to prevent confusion, normalizations are not applied when
      # attributes are fetched from the database. This means that if a record
      # was persisted before a normalization was declared, the relevant
      # attributes will not be normalized until either they are assigned new
      # values, or they are explicitly migrated via +normalize_attribute+.
      #
      # Because normalizations may be applied multiple times, they should be
      # _idempotent_. In other words, applying a normalization more than once
      # should have the same result as applying it only once.
      #
      # Normalizations, by default, are not applied to +nil+ values. This
      # behavior can be changed with the +:including_nil_values+ option.
      #
      # ==== Options
      #
      # * <tt>:with</tt> - The normalization to apply. May be specified as
      #   either a callable or a Symbol which will be converted to a Proc.
      # * <tt>:including_nil_values</tt> - Whether to apply normalizations to
      #   +nil+ values. Defaults to +false+.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     normalizes :email, with: -> email { email.strip.downcase }
      #   end
      #
      #   user = User.create(email: " CRUISE-CONTROL@EXAMPLE.COM\n")
      #   user.email                  # => "cruise-control@example.com"
      #
      #   user = User.find_by(email: "\tCRUISE-CONTROL@EXAMPLE.COM ")
      #   user.email                  # => "cruise-control@example.com"
      #   user.email_before_type_cast # => "cruise-control@example.com"
      #
      #   User.where(email: "\tCRUISE-CONTROL@EXAMPLE.COM ").first       # => user
      #   User.where("email = ?", "\tCRUISE-CONTROL@EXAMPLE.COM ").first # => nil
      def normalizes(*names, including_nil_values: false, with:)
        with = with.to_proc if with.is_a?(Symbol)

        names.each do |name|
          attribute(name) do |cast_type|
            NormalizedValueType.new(cast_type: cast_type, normalizer: with, normalize_nil: including_nil_values)
          end
        end

        self.normalized_attributes += names.map(&:to_sym)
      end

      # Normalizes a given +value+ using normalizations declared for +name+.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     normalizes :email, with: -> email { email.strip.downcase }
      #   end
      #
      #   User.normalize(:email, " CRUISE-CONTROL@EXAMPLE.COM\n")
      #   # => "cruise-control@example.com"
      def normalize(name, value)
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
        attr_reader :cast_type, :normalizer, :normalize_nil
        alias :normalize_nil? :normalize_nil

        def initialize(cast_type:, normalizer:, normalize_nil:)
          @cast_type = cast_type
          @normalizer = normalizer
          @normalize_nil = normalize_nil
          super(cast_type)
        end

        def normalize(value)
          normalizer.call(value) unless value.nil? && !normalize_nil?
        end

        def cast(value)
          normalize(super(value))
        end

        def serialize_for_query(value)
          super(cast(value))
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
      end
  end
end

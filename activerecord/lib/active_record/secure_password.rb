# frozen_string_literal: true

require "active_support/core_ext/hash/except"

module ActiveRecord
  module SecurePassword
    extend ActiveSupport::Concern

    include ActiveModel::SecurePassword

    module ClassMethods
      def has_secure_password(...) # :nodoc:
        super
        @@dummy_password ||= ActiveModel::SecurePassword.create("dummy")
      end

      # Given a set of attributes, finds a record using the non-password
      # attributes, and then authenticates that record using the password
      # attributes. Returns the record if it authenticates; otherwise, returns
      # +nil+. Regardless of whether a record is found or authenticated, all
      # password attributes are evaluated such that this method takes the same
      # amount of time when given the same number of password attributes. This
      # prevents timing-based enumeration attacks, wherein an attacker can
      # determine if a passworded record exists even without knowing the correct
      # password.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #   end
      #
      #   User.create(name: "John Doe", email: "jdoe@example.com", password: "abc123")
      #
      #   User.authenticate_by(email: "jdoe@example.com", password: "abc123").name # => "John Doe" (in 2.039ms)
      #   User.authenticate_by(email: "jdoe@example.com", password: "wrong")       # => nil (in 2.010ms)
      #   User.authenticate_by(email: "wrong@example.com", password: "abc123")     # => nil (in 2.019ms)
      def authenticate_by(attributes)
        passwords = attributes.select { |name, value| !has_attribute?(name) && has_attribute?("#{name}_digest") }

        raise ArgumentError, "One or more password arguments are required" if passwords.empty?
        raise ArgumentError, "One or more finder arguments are required" if passwords.size == attributes.size

        if record = find_by(attributes.except(*passwords.keys))
          record if passwords.map { |name, value| record.public_send("authenticate_#{name}", value) }.all?
        else
          passwords.each { |name, value| @@dummy_password.is_password?(value) }
          nil
        end
      end
    end
  end
end

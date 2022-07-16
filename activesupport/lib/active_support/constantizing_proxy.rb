# frozen_string_literal: true

require "active_support/proxy_object"

module ActiveSupport
  class ConstantizingProxy < ProxyObject # :nodoc:
    def initialize(constant_name)
      @constant_name = constant_name
    end

    def __constantized__
      @constantized ||= @constant_name.constantize
    end

    delegate_missing_to :__constantized__
  end

  def self.ConstantizingProxy(value)
    value.is_a?(String) ? ConstantizingProxy.new(value) : value
  end
end

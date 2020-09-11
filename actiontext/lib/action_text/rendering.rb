# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors_per_thread"

module ActionText
  module Rendering #:nodoc:
    thread_cattr_accessor :callable, instance_accessor: false

    class << self
      def with_callable(callable)
        previous_callable = self.callable
        self.callable = callable
        yield
      ensure
        self.callable = previous_callable
      end

      def render(*args, &block)
        callable.call(*args, &block)
      end
    end

    extend ActiveSupport::Concern

    included do
      delegate :renderer, to: :class
    end

    class_methods do
      def renderer
        Rendering
      end

      def renderer=(renderer)
        Rendering.callable = renderer.method(:render)
      end
    end
  end
end

ActiveSupport.run_load_hooks :action_text_rendering, ActionText::Rendering

# frozen_string_literal: true

module ActiveJob
  module Instrumentation #:nodoc:
    extend ActiveSupport::Concern

    included do
      around_enqueue do |_, block|
        scheduled_at ? instrument(:enqueue_at, &block) : instrument(:enqueue, &block)
      end

      around_perform do |_, block|
        instrument :perform_start
        instrument :perform, &block
      end
    end

    private
      def instrument(operation, payload = {}, &block)
        payload[:job] = self
        payload[:adapter] = queue_adapter

        ActiveSupport::Notifications.instrument("#{operation}.active_job", payload) do
          block.call if block
          payload[:aborted] = @_halted_callback_hook_called if defined?(@_halted_callback_hook_called)
          @_halted_callback_hook_called = nil
        end
      end

      def halted_callback_hook(*)
        super
        @_halted_callback_hook_called = true
      end
  end
end

# frozen_string_literal: true

require "minitest/mock"

module ActiveSupport
  module Testing
    module MethodCallAssertions # :nodoc:
      private
        def assert_called(object, method_name, message = nil, times: 1, returns: nil, &block)
          times_called = 0

          object.stub(method_name, proc { times_called += 1; returns }, &block)

          error = "Expected #{method_name} to be called #{times} times, " \
            "but was called #{times_called} times"
          error = "#{message}.\n#{error}" if message
          assert_equal times, times_called, error
        end

        def assert_called_with(object, method_name, args, returns: nil, &block)
          mock = Minitest::Mock.new
          mock.expect(:call, returns, args)

          object.stub(method_name, mock, &block)

          assert_mock(mock)
        end

        MockExpectingCalls = DelegateClass(Minitest::Mock) do
          def initialize(mock = Minitest::Mock.new)
            super
          end

          def expect(...)
            super(:call, ...)
          end
        end

        def assert_expected_calls(object, method_name, &block)
          mock = MockExpectingCalls.new

          object.stub(method_name, mock) do
            block.call(mock)
          end

          assert_mock(mock)
        end

        def assert_not_called(object, method_name, message = nil, &block)
          assert_called(object, method_name, message, times: 0, &block)
        end

        def assert_called_on_instance_of(klass, method_name, message = nil, times: 1, returns: nil)
          times_called = 0
          klass.define_method("stubbed_#{method_name}") do |*|
            times_called += 1

            returns
          end

          klass.alias_method "original_#{method_name}", method_name
          klass.alias_method method_name, "stubbed_#{method_name}"

          yield

          error = "Expected #{method_name} to be called #{times} times, but was called #{times_called} times"
          error = "#{message}.\n#{error}" if message

          assert_equal times, times_called, error
        ensure
          klass.alias_method method_name, "original_#{method_name}"
          klass.undef_method "original_#{method_name}"
          klass.undef_method "stubbed_#{method_name}"
        end

        def assert_not_called_on_instance_of(klass, method_name, message = nil, &block)
          assert_called_on_instance_of(klass, method_name, message, times: 0, &block)
        end

        def stub_any_instance(klass, instance: klass.new)
          klass.stub(:new, instance) { yield instance }
        end
    end
  end
end

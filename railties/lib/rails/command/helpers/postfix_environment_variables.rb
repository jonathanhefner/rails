# frozen_string_literal: true

module Rails
  module Command
    module Helpers
      module PostfixEnvironmentVariables # :nodoc:
        def initialize(args, ...)
          args.reject! do |arg|
            if arg =~ /\A(\w+)=(.*)/m
              ENV[$1] = $2
            end
          end

          super
        end
      end
    end
  end
end

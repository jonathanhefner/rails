# frozen_string_literal: true

require "active_support/core_ext/module/introspection"

module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes, include_path_helpers = true)
        Module.new do
          define_method(:include_routes_url_helpers!) do
            if namespace = module_parents.detect { |m| m.respond_to?(:railtie_routes_url_helpers) }
              include(namespace.railtie_routes_url_helpers(include_path_helpers))
            else
              include(routes.url_helpers(include_path_helpers))
            end
          end

          def self.extended(klass)
            # klass.include_routes_url_helpers!
          end

          define_method(:inherited) do |klass|
            super(klass)
            klass.include_routes_url_helpers!
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "action_controller/renderer" ################

module ActionText
  module Rendering # :nodoc:
    def render(*args, &block)
      ActionController.renderer.render_to_string(*args, &block)
    end
  end
end

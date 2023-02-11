# frozen_string_literal: true

require "rails/command/environment_argument"
require "rails/dockerfile_helpers"

module Rails
  module Command
    class DockerCommand < Base # :nodoc:
      include EnvironmentArgument
      class_option :environment, hide: true

      desc "render", "Render Dockerfile template to Dockerfile"
      option :template, banner: "PATH", type: :string, default: "config/Dockerfile.erb",
        desc: "The template to render (path relative to app root)."
      option :dockerfile, banner: "PATH", type: :string, default: "Dockerfile",
        desc: "The output file (path relative to app root)."
      option :environment, aliases: "-e", type: :string, default: "production",
          desc: "The RAILS_ENV to use for the Dockerfile."
      def render
        load_environment_config!

        result = Object.new.extend(DockerfileHelpers).render(options[:template])
        result.prepend("# syntax = docker/dockerfile:1\n\n") unless result.start_with?("# syntax = ")
        result.sub!(/\A# syntax.+\n/) { |directive| "#{directive}\n#{this_file_was_rendered_message}" }

        Rails.root.join(options[:dockerfile]).write(result)
      end

      private
        def this_file_was_rendered_message
          render_command = executable(:render)
          render_command << " --template=#{options[:template]}" if nondefault?(:template)
          render_command << " --dockerfile=#{options[:dockerfile]}" if nondefault?(:dockerfile)

          <<~MESSAGE
            ########################################################################
            # This file was rendered from `#{options[:template]}`.
            #
            # Instead of editing this file, edit `#{options[:template]}`, then run
            # `#{render_command}`.
            ########################################################################
          MESSAGE
        end

        def nondefault?(option)
          options[option] != self.class.commands[current_subcommand].options[option].default
        end
    end
  end
end

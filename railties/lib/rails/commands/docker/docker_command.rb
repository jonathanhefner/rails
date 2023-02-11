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
        desc: "The template to render."
      option :dockerfile, banner: "PATH", type: :string, default: "Dockerfile",
        desc: "The output file."
      option :environment, aliases: "-e", type: :string, default: "production",
          desc: "The RAILS_ENV to use for the Dockerfile."
      def render
        load_environment_config!

        result = Object.new.extend(DockerfileHelpers).render(options[:template])
        unless result.start_with?("# syntax = ")
          result = "# syntax = docker/dockerfile:1\n\n#{result}"
        end

        Rails.root.join(options[:dockerfile]).write(result)
      end
    end
  end
end

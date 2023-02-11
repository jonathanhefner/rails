# frozen_string_literal: true

require "rails/dockerfile_helpers"

module Rails
  module Command
    class DockerCommand < Base # :nodoc:
      desc "render", "Render Dockerfile template to Dockerfile"
      option :template, banner: "PATH", type: :string, default: "config/Dockerfile.erb",
        desc: "The template to render."
      option :dockerfile, banner: "PATH", type: :string, default: "Dockerfile",
        desc: "The output file."
      def render
        require_application!

        result = Object.new.extend(DockerfileHelpers).render(options[:template])
        unless result.start_with?("# syntax = ")
          result = "# syntax = docker/dockerfile:1\n\n#{result}"
        end

        Rails.root.join(options[:dockerfile]).write(result)
      end
    end
  end
end

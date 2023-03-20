# frozen_string_literal: true

module Rails
  module Command
    class RakeCommand < Base # :nodoc:
      extend Rails::Command::Actions

      namespace "rake"

      class << self
        def printing_commands
          formatted_rake_tasks
        end

        def perform(task, args, config)
          require_rake

          Rake.with_application do |rake|
            rake.init("rails", [task, *args])
            rake.load_rakefile

            if unrecognized_task = rake.top_level_tasks.find { |task| !rake.lookup(task[/[^\[]+/]) }
              @rake_tasks = rake.tasks
              raise UnrecognizedCommandError.new(unrecognized_task)
            end

            if Rails.respond_to?(:root)
              rake.options.suppress_backtrace_pattern = /\A(?!#{Regexp.quote(Rails.root.to_s)})/
            end
            rake.standard_exception_handling { rake.top_level }
          end
        end

        private
          def rake_tasks
            @rake_tasks ||= begin
              require_rake
              require_application!
              Rake.application.instance_variable_set(:@name, "rails")
              load_tasks
              Rake.application.tasks
            end
          end

          def formatted_rake_tasks
            rake_tasks.filter_map { |t| [ t.name_with_args, t.comment ] if t.comment }
          end

          def require_rake
            require "rake" # Defer booting Rake until we know it's needed.
            Rake::TaskManager.record_task_metadata = true # Preserve task comments.
          end
      end
    end
  end
end

# frozen_string_literal: true

require "rails/command"
require "rails/commands/rake/rake_command"
require "rails/test_unit/runner"
require "rails/test_unit/reporter"

module Rails
  module Command
    class TestCommand < Base # :nodoc:
      def self.executable(*args)
        args.empty? ? Rails::TestUnitReporter.executable : super
      end

      no_commands do
        def help(command_name = nil, ...)
          super
          if command_name
            say ""
            say self.class.class_usage
          end
          say ""
          Minitest.run(%w(--help))
        end
      end

      desc "test [paths...]", "yo yo"
      def perform(*)
        $LOAD_PATH << Rails::Command.root.join("test").to_s

        Rails::TestUnit::Runner.parse_options(args)
        run_prepare_task(args)
        Rails::TestUnit::Runner.run(args)
      end

      # Define Thor tasks to avoid going through Rake and booting twice when using bin/rails test:*

      Rails::TestUnit::Runner::TEST_FOLDERS.each do |name|
        define_method(name) do |*|
          args.prepend("test/#{name}")
          perform
        end
      end

      desc "test:all", "Runs all tests, including system tests", hide: true
      def all(*)
        @force_prepare = true
        args.prepend("test/**/*_test.rb")
        perform
      end

      def system(*)
        @force_prepare = true
        args.prepend("test/system")
        perform
      end

      def generators(*)
        args.prepend("test/lib/generators")
        perform
      end

      private
        def run_prepare_task(args)
          if @force_prepare || args.empty?
            Rails::Command::RakeCommand.perform("test:prepare", [], {})
          end
        rescue UnrecognizedCommandError => error
          raise unless error.name == "test:prepare"
        end
    end
  end
end

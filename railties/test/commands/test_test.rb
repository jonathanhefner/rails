# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::TestTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "test command with no args runs test:prepare task" do
    assert_calls_test_prepare do
      run_test_command("test")
    end
  end

  test "test command with args runs test:prepare task" do
    assert_calls_test_prepare do
      run_test_command("test", "test/*_test.rb")
    end
  end

  test "test command runs successfully when no tasks defined" do
    app_file "Rakefile", ""
    assert_successful_run run_test_command("test")
  end

  test "test:all runs test:prepare task" do
    assert_calls_test_prepare do
      run_test_command("test:all")
    end
  end

  test "test:system runs test:prepare task" do
    assert_calls_test_prepare do
      run_test_command("test:system")
    end
  end

  test "test:* runs test:prepare task" do
    assert_calls_test_prepare do
      run_test_command("test:models")
    end
  end

  private
    def run_test_command(subcommand = "test", *args, **options)
      rails subcommand, args, **options
    end

    def enhance_test_prepare_task(output:)
      app_file "Rakefile", <<~RUBY, "a"
        task :enhancing do
          puts #{output.inspect}
        end
        Rake::Task["test:prepare"].enhance(["enhancing"])
      RUBY
    end

    def assert_successful_run(test_command_output)
      assert_match "0 failures, 0 errors", test_command_output
    end

    def assert_calls_test_prepare(&block)
      enhance_test_prepare_task(output: "Prepare yourself!")
      output = block.call
      assert_match "Prepare yourself!", output
      output
    end
end

# frozen_string_literal: true

require "abstract_unit"

class Minitest::RailsPluginTest < ActiveSupport::TestCase
  setup do
    @original_backtrace_filter, Minitest.backtrace_filter = Minitest.backtrace_filter, Minitest::BacktraceFilter.new
    @original_reporter, Minitest.reporter = Minitest.reporter, Minitest::CompositeReporter.new

    @options = Minitest.process_args []
    @output = StringIO.new("".encode("UTF-8"))
  end

  teardown do
    Minitest.backtrace_filter = @original_backtrace_filter
    Minitest.reporter = @original_reporter
  end

  test "default reporters are replaced" do
    Minitest.reporter << Minitest::SummaryReporter.new(@output, @options)
    Minitest.reporter << Minitest::ProgressReporter.new(@output, @options)
    Minitest.reporter << Minitest::Reporter.new(@output, @options)

    Minitest.plugin_rails_init({})

    assert_equal 3, Minitest.reporter.reporters.count
    assert Minitest.reporter.reporters.any? { |candidate| candidate.kind_of?(Minitest::SuppressedSummaryReporter) }
    assert Minitest.reporter.reporters.any? { |candidate| candidate.kind_of?(::Rails::TestUnitReporter) }
    assert Minitest.reporter.reporters.any? { |candidate| candidate.kind_of?(Minitest::Reporter) }
  end

  test "no custom reporters are added if nothing to replace" do
    Minitest.plugin_rails_init({})

    assert_empty Minitest.reporter.reporters
  end

  test "replaces the default backtrace_filter" do
    Dir.chdir(::Rails.root) do
      Minitest.plugin_rails_init({})
    end

    assert_kind_of ::Rails::BacktraceCleaner, Minitest.backtrace_filter
  end

  test "uses a generic backtrace cleaner when outside of a Rails app" do
    Dir.chdir(__dir__) do
      Minitest.plugin_rails_init({})
    end

    assert_instance_of ::ActiveSupport::BacktraceCleaner, Minitest.backtrace_filter
  end
end

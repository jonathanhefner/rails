# frozen_string_literal: true

require "abstract_unit"
require "rails/command"
require "rails/command/helpers/postfix_environment_variables"

class Rails::Command::Helpers::PostfixEnvironmentVariablesTest < ActiveSupport::TestCase
  setup do
    @original_env = ENV.to_h
  end

  teardown do
    ENV.replace(@original_env)
  end

  class RememberRecentCommand < Rails::Command::Base
    include Rails::Command::Helpers::PostfixEnvironmentVariables

    singleton_class.attr_accessor :recent_env
    singleton_class.attr_accessor :recent_args

    def remember(*args)
      self.class.recent_env = ENV.to_h
      self.class.recent_args = args
    end
  end

  test "adds postfix environment variables to ENV" do
    RememberRecentCommand.perform("remember", ["FOO_BAR=abc", "BAZ=def\nxyz", "QUX="], {})
    assert_equal "abc", RememberRecentCommand.recent_env["FOO_BAR"]
    assert_equal "def\nxyz", RememberRecentCommand.recent_env["BAZ"]
    assert_equal "", RememberRecentCommand.recent_env["QUX"]
  end

  test "removes postfix environment variables from command args" do
    RememberRecentCommand.perform("remember", ["foo", "BAZ=1", "bar", "QUX=1"], {})
    assert_equal ["foo", "bar"], RememberRecentCommand.recent_args
  end
end

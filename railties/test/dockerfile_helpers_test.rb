# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/dockerfile_helpers"

class DockerfileHelpersTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include EnvHelpers

  setup :build_app
  teardown :teardown_app

  # test "#render"
  # test "#install_packages"
  # test "#install_gems"
  # test "#install_node"
  # test "#install_node_modules"
  # test "#prepare_app"

  test "#gem? returns true when the gem is used in the current environment" do
    with_rails_env "development" do
      assert helpers.gem?("web-console")

      assert helpers.gem?("actionpack")
      assert_not helpers.gem?("does_not_exist")
    end
  end

  test "#gem? returns false when the gem is not used in the current environment" do
    with_rails_env "production" do
      assert_not helpers.gem?("web-console")

      assert helpers.gem?("actionpack")
      assert_not helpers.gem?("does_not_exist")
    end
  end

  test "#gem? supports version constraints" do
    assert helpers.gem?("actionpack", ">= 1", "<= 9000")
    assert_not helpers.gem?("actionpack", "> 9000")
  end

  # test "#api_only?"
  # test "#node?"
  # test "#ruby_version"
  # test "#node_version"
  # test "#yarn_version"
  # test "#rails_packages"
  # test "#node_packages"

  test "#runtime_db_packages" do
    option_packages = {
      mysql: "default-mysql-client",
      postgresql: "postgresql-client",
      redis: "redis",
      sqlite: "libsqlite3-0",
    }

    assert_option_packages option_packages do |options|
      helpers.runtime_db_packages(**options)
    end

  end

  test "#runtime_packages" do
    assert_not_packages "build-essential", helpers.runtime_packages
    assert_packages helpers.runtime_db_packages, helpers.runtime_packages
    assert_packages helpers.rails_packages, helpers.runtime_packages
  end

  test "#buildtime_db_packages" do
    option_packages = {
      mysql: "default-libmysqlclient-dev",
      postgresql: "libpq-dev",
      redis: "redis",
    }

    assert_option_packages option_packages do |options|
      helpers.buildtime_db_packages(**options)
    end
  end

  test "#buildtime_packages" do
    assert_packages "build-essential", helpers.buildtime_packages
    assert_packages helpers.buildtime_db_packages, helpers.buildtime_packages
    assert_packages helpers.rails_packages, helpers.buildtime_packages

    # TODO node_packages
  end

  private
    def helpers
      @helpers ||= begin
        Bundler.reset_paths!
        Bundler.ui.level = "silent"
        ENV["BUNDLE_GEMFILE"] = app_path("Gemfile")
        quietly { require "#{app_path}/config/environment" }
        Object.new.extend(Rails::DockerfileHelpers)
      end
    end

    def assert_packages(expected, actual)
      Array(expected).each { |package| assert_includes actual, package }
    end

    def assert_not_packages(unexpected, actual)
      Array(unexpected).each { |package| assert_not_includes actual, package }
    end

    def assert_option_packages(option_packages, &block)
      option_packages.each do |option, packages|
        assert_packages packages, block.call({ option => true })
      end

      assert_not_packages option_packages.values.flatten, block.call(option_packages.transform_values { false })
    end
end

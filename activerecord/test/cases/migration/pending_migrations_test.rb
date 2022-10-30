# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    if current_adapter?(:SQLite3Adapter) && !in_memory_db?
      class PendingMigrationsTest < ActiveRecord::TestCase
        self.use_transactional_tests = false

        setup do
          @tmp_dir = Dir.mktmpdir("pending_migrations_test-")

          @original_configurations = ActiveRecord::Base.configurations
          ActiveRecord::Base.configurations = base_config
          ActiveRecord::Base.establish_connection(:primary)
        end

        teardown do
          ActiveRecord::Base.configurations = @original_configurations
          ActiveRecord::Base.establish_connection(:arunit)
          FileUtils.rm_rf(@tmp_dir)
        end

        def run_migrations
          migrator = Base.connection.migration_context
          capture(:stdout) { migrator.migrate }
        end

        def create_migration(number, name, database: :primary)
          migration_dir = migrations_path_for(database)
          FileUtils.mkdir_p(migration_dir)

          filename = "#{number}_#{name.underscore}.rb"
          File.write(File.join(migration_dir, filename), <<~RUBY)
            class #{name.classify} < ActiveRecord::Migration::Current
            end
          RUBY
        end

        def test_errors_if_pending
          create_migration "01", "create_foo"
          assert_pending_migrations
        end

        def test_checks_if_supported
          run_migrations
          assert_no_pending_migrations
        end

        def test_okay_with_no_migrations
          assert_no_pending_migrations
        end

        # Regression test for https://github.com/rails/rails/pull/29759
        def test_understands_migrations_created_out_of_order
          # With a prior file before even initialization
          create_migration "05", "create_bar"
          quietly { run_migrations }
          assert_no_pending_migrations

          # It understands the new migration created at 01
          create_migration "01", "create_foo"
          assert_pending_migrations
        end

        def test_with_multiple_database
          create_migration "01", "create_bar", database: :secondary
          assert_pending_migrations

          ActiveRecord::Base.establish_connection(:secondary)
          quietly { run_migrations }

          ActiveRecord::Base.establish_connection(:primary)

          assert_no_pending_migrations

          # Now check exclusion if database_tasks is set to false for the db_config
          create_migration "02", "create_foo", database: :secondary
          assert_pending_migrations

          ActiveRecord::Base.configurations = base_config(database_tasks: false)
          assert_no_pending_migrations
        end

        def test_with_stdlib_logger
          old, ActiveRecord::Base.logger = ActiveRecord::Base.logger, ::Logger.new(StringIO.new)
          assert_nothing_raised { CheckPending.new(proc { }).call({}) }
        ensure
          ActiveRecord::Base.logger = old
        end

        private
          def assert_pending_migrations
            # Do twice to test that the error continues to be raised.
            2.times do
              assert_raises ActiveRecord::PendingMigrationError do
                CheckPending.new(proc { flunk }).call({})
              end
            end
          end

          def assert_no_pending_migrations
            app = Minitest::Mock.new
            check_pending = CheckPending.new(app)

            # Do twice to also test the cached result.
            2.times do
              app.expect :call, nil, [{}]
              check_pending.call({})
              app.verify
            end
          end

          def database_path_for(database_name)
            File.join(@tmp_dir, "#{database_name}.sqlite3")
          end

          def migrations_path_for(database_name)
            File.join(@tmp_dir, "#{database_name}-migrations")
          end

          def base_config(**config_options)
            {
              ActiveRecord::ConnectionHandling::DEFAULT_ENV.call => {
                primary: {
                  adapter: "sqlite3",
                  database: database_path_for(:primary),
                  migrations_paths: migrations_path_for(:primary),
                  **config_options,
                },
                secondary: {
                  adapter: "sqlite3",
                  database: database_path_for(:secondary),
                  migrations_paths: migrations_path_for(:secondary),
                  **config_options,
                },
              }
            }
          end
      end
    end
  end
end

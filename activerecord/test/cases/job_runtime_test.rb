# frozen_string_literal: true

require "cases/helper"
require "active_record/railties/job_runtime"

begin
  require_relative "../../../activejob/lib/active_job"
rescue LoadError => error
  $stderr.print "Failed to load Active Job. Skipping JobRuntime tests: #{error}"
end

class JobRuntimeTest < ActiveSupport::TestCase
  if defined?(ActiveJob)
    class TestJob < ActiveJob::Base
      include ActiveRecord::Railties::JobRuntime

      def perform(*)
        ActiveRecord::LogSubscriber.runtime += 42
      end
    end
  else
    setup :skip
  end

  test "job notification payload includes db_runtime" do
    ActiveRecord::LogSubscriber.runtime = 0

    assert_equal 42, notification_payload[:db_runtime]
  end

  test "db_runtime tracks database runtime for job only" do
    ActiveRecord::LogSubscriber.runtime = 100

    assert_equal 42, notification_payload[:db_runtime]
    assert_equal 142, ActiveRecord::LogSubscriber.runtime
  end

  private
    def notification_payload
      payload = nil
      subscriber = ActiveSupport::Notifications.subscribe("perform.active_job") do |*, _payload|
        payload = _payload
      end

      ActiveJob::Base.logger.silence do
        TestJob.perform_now
      end

      ActiveSupport::Notifications.unsubscribe(subscriber)

      payload
    end
end

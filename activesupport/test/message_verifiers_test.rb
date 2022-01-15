# frozen_string_literal: true

require_relative "rotation_coordinator_tests"

class MessageVerifiersTest < ActiveSupport::TestCase
  include RotationCoordinatorTests

  test "can override secret generator" do
    overridden = make_coordinator.rotate(secret_generator: -> (salt) { salt + "!" })

    assert_equal "message", roundtrip("message", overridden["salt"])
    assert_nil roundtrip("message", @coordinator["salt"], overridden["salt"])
  end

  private
    def make_coordinator
      ActiveSupport::MessageVerifiers.new { |salt| salt * 10 }
    end

    def roundtrip(message, signer, verifier = signer)
      verifier.verified(signer.generate(message))
    end
end

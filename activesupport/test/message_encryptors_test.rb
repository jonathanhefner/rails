# frozen_string_literal: true

require_relative "rotation_coordinator_tests"

class MessageEncryptorsTest < ActiveSupport::TestCase
  include RotationCoordinatorTests

  test "can override secret generator" do
    overridden = make_coordinator.rotate(secret_generator: -> (salt, secret_length) { salt[0] * secret_length })

    assert_equal "message", roundtrip("message", overridden["salt"])
    assert_nil roundtrip("message", @coordinator["salt"], overridden["salt"])
  end

  test "supports separate secrets for encryption and signing" do
    separate = ActiveSupport::MessageEncryptors.new { |*args| [SECRET_GENERATOR.call(*args), "signing secret"] }.rotate_defaults

    assert_equal "message", roundtrip("message", separate["salt"])
    assert_nil roundtrip("message", @coordinator["salt"], separate["salt"])
  end

  private
    SECRET_GENERATOR = -> (salt, secret_length) { "".ljust(secret_length, salt) }

    def make_coordinator
      ActiveSupport::MessageEncryptors.new(&SECRET_GENERATOR)
    end

    def roundtrip(message, encryptor, decryptor = encryptor)
      decryptor.decrypt_and_verify(encryptor.encrypt_and_sign(message))
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
end

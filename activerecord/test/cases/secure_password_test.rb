# frozen_string_literal: true

require "cases/helper"
require "models/user"

class SecurePasswordTest < ActiveRecord::TestCase
  setup do
    # Speed up tests
    @original_min_cost = ActiveModel::SecurePassword.min_cost
    ActiveModel::SecurePassword.min_cost = true

    @user = User.create(password: "abc123", recovery_password: "123abc")
  end

  teardown do
    ActiveModel::SecurePassword.min_cost = @original_min_cost
  end

  test "authenticates record when password is correct" do
    assert_equal @user, User.authenticate_by(token: @user.token, password: @user.password)
  end

  test "does not authenticate record when password is incorrect" do
    assert_nil User.authenticate_by(token: @user.token, password: "wrong")
  end

  test "finds record using multiple attributes" do
    assert_equal @user, User.authenticate_by(token: @user.token, auth_token: @user.auth_token, password: @user.password)
    assert_nil User.authenticate_by(token: @user.token, auth_token: "wrong", password: @user.password)
  end

  test "authenticates record using multiple passwords" do
    assert_equal @user, User.authenticate_by(token: @user.token, password: @user.password, recovery_password: @user.recovery_password)
    assert_nil User.authenticate_by(token: @user.token, password: @user.password, recovery_password: "wrong")
  end

  test "digests passwords when record is not found" do
    dummy_password = ActiveRecord::SecurePassword::ClassMethods.class_variable_get(:@@dummy_password)

    assert_called_with(dummy_password, :is_password?, [["wrong2"], ["wrong3"]]) do
      assert_nil User.authenticate_by(token: "wrong1", password: "wrong2", recovery_password: "wrong3")
    end
  end

  test "requires at least one password" do
    assert_raises ArgumentError do
      User.authenticate_by(token: @user.token)
    end
  end

  test "requires at least one attribute" do
    assert_raises ArgumentError do
      User.authenticate_by(password: @user.password)
    end
  end
end

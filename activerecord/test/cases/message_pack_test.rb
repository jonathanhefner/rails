# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/comment"
require "models/post"
require "active_support/message_pack"
require "active_record/message_pack"

class ActiveRecordMessagePackTest < ActiveRecord::TestCase
  test "roundtrips record and cached associations" do
    post = Post.create!(title: "A Title", body: "A body.")
    post.create_author!(name: "An Author")
    post.comments.create!(body: "A comment.")
    post.comments.create!(body: "Another comment.", author: post.author)
    post.comments.load

    assert_no_queries do
      roundtripped_post = roundtrip(post)

      assert_equal post, roundtripped_post
      assert_equal post.author, roundtripped_post.author
      assert_equal post.comments, roundtripped_post.comments
      assert_equal post.comments.map(&:author), roundtripped_post.comments.map(&:author)

      assert_same roundtripped_post, roundtripped_post.comments[0].post
      assert_same roundtripped_post, roundtripped_post.comments[1].post
      assert_same roundtripped_post.author, roundtripped_post.comments[1].author
    end
  end

  private
    def roundtrip(input)
      serialized = ActiveSupport::MessagePack.dump(ActiveRecord::MessagePack.dump(input))
      ActiveRecord::MessagePack.load(ActiveSupport::MessagePack.load(serialized))
    end
end

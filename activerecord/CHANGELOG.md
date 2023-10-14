*   Add `ActiveRecord::Base::normalizes_attributes_of_type`, which behaves like
    `ActiveRecord::Base::normalizes`, but targets attributes having one of the
    specified types. For example:

      ```ruby
      class Snippet < ActiveRecord::Base
        normalizes_attributes_of_type :string, :text, except: [:code], with: -> { _1.strip }
      end

      snippet = Snippet.new(title: "  Title", description: "Description.\n", code: "  code\n")
      snippet.title        # => "Title"
      snippet.description  # => "Description."
      snippet.code         # => "  code\n"
      ```

    *Niklas Häusele* and *Jonathan Hefner*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.

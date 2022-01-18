*   Add `ActiveModel::CompositeValidator`.

    `CompositeValidator` is a base class that can be used to compose
    existing validators.  Subclasses define a `compose` method that calls
    `validates*` methods in the same way a model class would:

    ```ruby
    class MoneyValidator < ActiveModel::CompositeValidator
      def compose
        currencies = options[:in]

        validates *attributes, numericality: { only_integer: true }
        validates *attributes.map { |attribute| "#{attribute}_currency" }, inclusion: currencies
      end
    end

    class Account < ActiveRecord::Base
      validates :balance, money: ["JPY"]
    end

    Account.new(balance: 100, balance_currency: "JPY").valid?   # => true
    Account.new(balance: 100.1, balance_currency: "JPY").valid? # => false
    Account.new(balance: 100, balance_currency: "USD").valid?   # => false
    ```

    *Jonathan Hefner*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activemodel/CHANGELOG.md) for previous changes.

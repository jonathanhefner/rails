# frozen_string_literal: true

module ActiveModel
  module AttributeMethods
    # +BeforeTypeCast+ provides a way to read the value of attributes before
    # type casting and deserialization. It uses AttributeMethods::ClassMethods#attribute_method_suffix
    # to define attribute methods with the following suffixes:
    #
    # * +_came_from_user?+
    # * +_before_type_cast+
    # * +_for_database+
    #
    # ==== Examples
    #
    #   class Task
    #     include ActiveModel::Attributes
    #
    #     attribute :completed_on, :date
    #   end
    #
    #   task = Task.new
    #   task.completed_on                  # => nil
    #   task.completed_on_came_from_user?  # => false
    #   task.completed_on_before_type_cast # => nil
    #   task.completed_on_for_database     # => nil
    #
    #   task.completed_on = "1999-12-31"
    #   task.completed_on                  # => Fri, 31 Dec 1999
    #   task.completed_on_came_from_user?  # => true
    #   task.completed_on_before_type_cast # => "1999-12-31"
    #   task.completed_on_for_database     # => Fri, 31 Dec 1999
    #
    module BeforeTypeCast
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "_before_type_cast", "_for_database", parameters: false
        attribute_method_suffix "_came_from_user?", parameters: false
      end

      # Returns the value of the attribute identified by +attr_name+ before
      # type casting and deserialization.
      #
      # ==== Examples
      #
      #   class Task
      #     include ActiveModel::Attributes
      #
      #     attribute :completed_on, :date
      #   end
      #
      #   task = Task.new
      #   task.completed_on = "1999-12-31"
      #
      #   task.read_attribute("completed_on")                  # => Fri, 31 Dec 1999
      #   task.read_attribute_before_type_cast("completed_on") # => "1999-12-31"
      #
      def read_attribute_before_type_cast(attr_name)
        name = attr_name.to_s
        name = self.class.attribute_aliases[name] || name

        attribute_before_type_cast(name)
      end

      # Returns a hash of attributes before type casting and deserialization.
      #
      # ==== Examples
      #
      #   class Task
      #     include ActiveModel::Attributes
      #
      #     attribute :completed_on, :date
      #   end
      #
      #   task = Task.new
      #   task.completed_on = "1999-12-31"
      #
      #   task.attributes                  # => {"completed_on"=>Fri, 31 Dec 1999}
      #   task.attributes_before_type_cast # => {"completed_on"=>"1999-12-31"}
      #
      def attributes_before_type_cast
        @attributes.values_before_type_cast
      end

      # Returns a hash of attributes for assignment to the database.
      def attributes_for_database
        @attributes.values_for_database
      end

      private
        # Dispatch target for <tt>*_before_type_cast</tt> attribute methods.
        def attribute_before_type_cast(attr_name)
          @attributes[attr_name].value_before_type_cast
        end

        # Dispatch target for <tt>*_for_database</tt> attribute methods.
        def attribute_for_database(attr_name)
          @attributes[attr_name].value_for_database
        end

        # Dispatch target for <tt>*_came_from_user?</tt> attribute methods.
        def attribute_came_from_user?(attr_name)
          @attributes[attr_name].came_from_user?
        end
    end
  end
end

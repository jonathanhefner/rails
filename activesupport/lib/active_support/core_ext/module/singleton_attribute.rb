# frozen_string_literal: true

class Module
  def singleton_attribute(*attribute_names, default: nil)
    attribute_names.each do |name|
      underlying_name = "_#{name}_singleton"

      singleton_class.attr_accessor(underlying_name)

      singleton_class.define_method(name, &method(underlying_name))
      singleton_class.define_method("#{name}=", &method("#{underlying_name}="))

      public_send("#{name}=", default)

      ### OR:
      # singleton_class.singleton_class.attr_accessor(name)

      # singleton_class.define_method(name, &singleton_class.method(name))
      # singleton_class.define_method("#{name}=", &singleton_class.method("#{name}="))

      # public_send("#{name}=", default)
    end
  end
end
